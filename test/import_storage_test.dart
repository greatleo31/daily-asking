import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/artifacts/artifact_repository.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/core/transfer/import_plan.dart';
import 'package:daily_asking/core/transfer/transfer_schema.dart';
import 'package:daily_asking/evidence/evidence_repository.dart';
import 'package:daily_asking/journal/journal_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('批量仓库写入', () {
    test('entries 合并更新与新增，一批只写一次并保持时间倒序', () async {
      final store = _Storage();
      final repo = LocalEntryRepository(JsonStore(store));
      await repo.save(_entry('existing', 2));
      store.writes.clear();
      final update = _entry('existing', 2)..task = 'updated';
      final incoming = _entry('new', 3)..tags = ['imported'];
      await repo.saveAll([_entry('old', 1), incoming, update]);
      expect(store.writes, {'entries_v1': 1});
      expect((await repo.list()).map((e) => e.id), ['new', 'existing', 'old']);
      expect((await repo.find('existing'))!.task, 'updated');
      incoming.task = 'mutated';
      incoming.tags.add('mutated');
      expect((await repo.find('new'))!.task, 'new');
      expect((await repo.find('new'))!.tags, ['imported']);
      expect(await _entryIdsOnDisk(store), ['new', 'existing', 'old']);
    });

    test('entries 失败无幽灵记录，失败更新保留原值', () async {
      final store = _Storage();
      final repo = LocalEntryRepository(JsonStore(store));
      await repo.save(_entry('existing', 1));
      store.failingKey = 'entries_v1';
      await expectLater(
        repo.saveAll([
          _entry('existing', 2)..task = 'changed',
          _entry('new', 3),
        ]),
        throwsStateError,
      );
      expect((await repo.list()).map((e) => e.id), ['existing']);
      expect((await repo.find('existing'))!.task, 'existing');
      expect(await _entryIdsOnDisk(store), ['existing']);
      // 既有单条保存/删除同样不得提前发布候选缓存。
      await expectLater(repo.save(_entry('single', 4)), throwsStateError);
      await expectLater(repo.delete('existing'), throwsStateError);
      expect((await repo.list()).map((e) => e.id), ['existing']);
    });

    test('批量合并读取最新落盘数据，不丢失长期缓存未见的记录', () async {
      final store = _Storage();
      final repo = LocalEntryRepository(JsonStore(store));
      expect(await repo.list(), isEmpty);
      await LocalEntryRepository(JsonStore(store)).save(_entry('external', 1));
      store.writes.clear();
      await repo.saveAll([_entry('imported', 2)]);
      expect(store.writes, {'entries_v1': 1});
      expect((await repo.list()).map((e) => e.id), ['imported', 'external']);
    });

    test('artifacts 合并批量写一次，按更新时间排序并隔离可变输入', () async {
      final store = _Storage();
      final repo = LocalArtifactRepository(JsonStore(store));
      await repo.save(_artifact('existing', 1));
      store.writes.clear();
      final imported = _artifact('new', 3);
      await repo.saveAll([
        imported,
        _artifact('existing', 2)..content = 'updated',
      ]);
      expect(store.writes, {'artifacts_v1': 1});
      expect((await repo.list()).map((a) => a.id), ['new', 'existing']);
      expect((await repo.find('existing'))!.content, 'updated');
      imported.content = 'mutated';
      imported.sourceEntryIds.add('mutated');
      imported.risks.add('mutated');
      imported.gaps.add('mutated');
      imported.structuredIssues.add('mutated');
      final saved = (await repo.find('new'))!;
      expect(saved.content, 'new');
      expect(saved.sourceEntryIds, ['entry']);
      expect(saved.risks, isEmpty);
      expect(saved.gaps, isEmpty);
      expect(saved.structuredIssues, isEmpty);
      store.failingKey = 'artifacts_v1';
      await expectLater(
        repo.saveAll([_artifact('ghost', 4)]),
        throwsStateError,
      );
      expect((await repo.list()).map((a) => a.id), ['new', 'existing']);
      await expectLater(repo.delete('existing'), throwsStateError);
      expect(await repo.find('existing'), isNotNull);
    });

    test('questions 与 answers 各写一次并保留单条保存/升序读取行为', () async {
      final store = _Storage();
      final repo = LocalEvidenceRepository(JsonStore(store));
      await repo.saveQuestion(_question('old', 'entry', 1));
      await repo.saveAnswer(_answer('old_a', 'old', 1));
      store.writes.clear();
      final question = _question('new', 'entry', 2);
      final answer = _answer('new_a', 'new', 2);
      await repo.saveAll(
        questions: [
          question,
          _question('old', 'entry', 1)..status = QuestionStatus.skip,
        ],
        answers: [answer, _answer('old_a', 'old', 1)..content = 'updated'],
      );
      expect(store.writes, {'questions_v1': 1, 'answers_v1': 1});
      expect((await repo.listQuestions()).map((q) => q.id), ['old', 'new']);
      expect((await repo.listAnswers()).map((a) => a.id), ['old_a', 'new_a']);
      expect(
        (await repo.questionsFor('entry')).first.status,
        QuestionStatus.skip,
      );
      expect((await repo.answersFor('old')).single.content, 'updated');
      question.status = QuestionStatus.answered;
      answer.content = 'mutated';
      expect(
        (await repo.questionsFor('entry')).last.status,
        QuestionStatus.pending,
      );
      expect((await repo.answersFor('new')).single.content, 'new_a');
    });

    for (final failingKey in ['questions_v1', 'answers_v1']) {
      test('$failingKey 失败：缓存只反映成功落盘的部分', () async {
        final store = _Storage();
        final repo = LocalEvidenceRepository(JsonStore(store));
        await repo.saveQuestion(_question('existing_q', 'existing', 1));
        await repo.saveAnswer(_answer('existing_a', 'existing_q', 1));
        store.writes.clear();
        store.failingKey = failingKey;
        await expectLater(
          repo.saveAll(
            questions: [_question('new_q', 'new', 2)],
            answers: [_answer('new_a', 'new_q', 2)],
          ),
          throwsStateError,
        );
        final disk = LocalEvidenceRepository(JsonStore(store));
        expect(
          (await repo.listQuestions()).map((q) => q.toJson()).toList(),
          (await disk.listQuestions()).map((q) => q.toJson()).toList(),
        );
        expect(
          (await repo.listAnswers()).map((a) => a.toJson()).toList(),
          (await disk.listAnswers()).map((a) => a.toJson()).toList(),
        );
        expect(
          (await repo.listQuestions()).length,
          failingKey == 'answers_v1' ? 2 : 1,
        );
        expect((await repo.listAnswers()).length, 1);
        expect(store.writes['questions_v1'], 1);
        expect(
          store.writes['answers_v1'],
          failingKey == 'answers_v1' ? 1 : null,
        );
      });
    }
  });

  group('AppState 数据交换', () {
    test('导入批量写三次，按真实日期排序且不改变伙伴、产物或设置', () async {
      final store = _Storage();
      final state = await AppState.debug(store);
      addTearDown(state.dispose);
      await state.bootstrap();
      await state.saveQuickToday('current');
      final currentId = state.allEntries.single.id;
      final companion = state.companion;
      final companionEvent = state.lastCompanionEvent;
      final companionRaw = store.values['companion_v1'];
      final artifacts = state.artifacts;
      final settings = state.llmSettings;
      final phase = state.companionStage;
      final plan = buildImportPlan(
        ParsedImport(
          candidates: [
            _candidate(_entry('oldest', 1)),
            _candidate(_entry('middle', 3), withEvidence: true),
            _candidate(_entry('older', 2)),
          ],
        ),
        existingEntries: state.allEntries,
        existingQuestions: const [],
        existingAnswers: const [],
        now: DateTime(2026, 9, 17),
      );
      store.writes.clear();
      var notifications = 0;
      state.addListener(() => notifications++);
      await state.importEntries(plan);
      expect(store.writes, {
        'entries_v1': 1,
        'questions_v1': 1,
        'answers_v1': 1,
      });
      expect(state.allEntries.map((e) => e.id), [
        currentId,
        'middle',
        'older',
        'oldest',
      ]);
      expect(state.todayEntries.map((e) => e.id), [currentId]);
      expect(state.metrics.totalEntries, 4);
      expect(state.metrics.tagCounts['#导入-20260917'], 3);
      expect((await state.questionsFor('middle')).single.id, 'q_middle');
      expect((await state.answersFor('q_middle')).single.id, 'a_middle');
      expect(state.companion, same(companion));
      expect(state.companionStage, phase);
      expect(state.lastCompanionEvent, same(companionEvent));
      expect(store.values['companion_v1'], companionRaw);
      expect(state.artifacts, same(artifacts));
      expect(state.llmSettings, same(settings));
      expect(notifications, 1);
    });

    test('导出读取最新持久化记录/全部追问/答案，不读设置、不依赖 UI 缓存', () async {
      final store = _Storage();
      final state = await AppState.debug(store);
      addTearDown(state.dispose);
      await state.bootstrap();
      final entries = LocalEntryRepository(JsonStore(store));
      final evidence = LocalEvidenceRepository(JsonStore(store));
      await entries.save(_entry('external', 1));
      await evidence.saveQuestion(
        _question('q', 'external', 1)..status = QuestionStatus.skip,
      );
      await evidence.saveAnswer(_answer('a', 'q', 1));
      store.values['settings_llm'] = 'sensitive configuration';
      store.reads.clear();
      final data = await state.exportTransferData();
      expect(data.entries.single.id, 'external');
      expect(data.questions.single.status, QuestionStatus.skip);
      expect(data.answers.single.id, 'a');
      expect(state.allEntries, isEmpty);
      expect(store.reads, {
        'entries_v1': 1,
        'questions_v1': 1,
        'answers_v1': 1,
      });
      data.entries.single.task = 'mutated snapshot';
      expect(
        (await state.exportTransferData()).entries.single.task,
        'external',
      );
    });

    for (final collision in ['entry', 'question', 'answer']) {
      test('过期计划 $collision ID 冲突在任何写入前被拒绝', () async {
        final store = _Storage();
        final state = await AppState.debug(store);
        addTearDown(state.dispose);
        await state.bootstrap();
        final incoming = _entry('incoming', 2);
        final plan = _plan([incoming], [_question('q', 'incoming', 2)], [
          _answer('a', 'q', 2),
        ]);
        final entries = LocalEntryRepository(JsonStore(store));
        final evidence = LocalEvidenceRepository(JsonStore(store));
        await entries.save(
          _entry(collision == 'entry' ? 'incoming' : 'existing', 1),
        );
        if (collision != 'entry') {
          await evidence.saveQuestion(
            _question(
              collision == 'question' ? 'q' : 'existing_q',
              'existing',
              1,
            ),
          );
        }
        if (collision == 'answer') {
          await evidence.saveAnswer(_answer('a', 'existing_q', 1));
        }
        final before = Map<String, String>.of(store.values);
        store.writes.clear();
        await expectLater(state.importEntries(plan), throwsStateError);
        expect(store.writes, isEmpty);
        expect(store.values, before);
      });
    }

    for (final failingKey in ['entries_v1', 'questions_v1', 'answers_v1']) {
      test('导入 $failingKey 失败：刷新实际落盘部分、通知且抛出原始异常', () async {
        final store = _Storage();
        final state = await AppState.debug(store);
        addTearDown(state.dispose);
        await state.bootstrap();
        final beforeCompanion = state.companion;
        var notifications = 0;
        state.addListener(() => notifications++);
        store.failingKey = failingKey;
        await expectLater(
          state.importEntries(
            _plan([_entry('entry', 1)], [_question('q', 'entry', 1)], [
              _answer('a', 'q', 1),
            ]),
          ),
          throwsA(same(store.failure)),
        );
        final disk = await state.exportTransferData();
        expect(
          state.allEntries.map((e) => e.id),
          disk.entries.map((e) => e.id),
        );
        expect(state.metrics.totalEntries, disk.entries.length);
        expect(state.metrics.openQuestionCount, disk.questions.length);
        expect(disk.entries.length, failingKey == 'entries_v1' ? 0 : 1);
        expect(disk.questions.length, failingKey == 'answers_v1' ? 1 : 0);
        expect(disk.answers, isEmpty);
        expect(state.companion, same(beforeCompanion));
        expect(store.writes.containsKey('companion_v1'), isFalse);
        expect(notifications, 1);
      });
    }

    test('空计划不写入、不成长、不发通知', () async {
      final store = _Storage();
      final state = await AppState.debug(store);
      addTearDown(state.dispose);
      await state.bootstrap();
      var notifications = 0;
      state.addListener(() => notifications++);
      await state.importEntries(_plan([], [], []));
      expect(store.writes, isEmpty);
      expect(notifications, 0);
    });
  });
}

Entry _entry(String id, int day) {
  final date = DateTime(2020, 1, day);
  return Entry(id: id, date: date, task: id, createdAt: date, updatedAt: date);
}

EvidenceQuestion _question(String id, String entryId, int day) {
  final date = DateTime(2020, 1, day);
  return EvidenceQuestion(
    id: id,
    entryId: entryId,
    kind: QuestionKind.result,
    prompt: 'result?',
    reason: '',
    status: QuestionStatus.pending,
    createdAt: date,
    updatedAt: date,
  );
}

EvidenceAnswer _answer(String id, String questionId, int day) => EvidenceAnswer(
  id: id,
  questionId: questionId,
  content: id,
  createdAt: DateTime(2020, 1, day),
);

Artifact _artifact(String id, int day) => Artifact(
  id: id,
  type: ArtifactType.weekly,
  content: id,
  sourceEntryIds: ['entry'],
  risks: [],
  gaps: [],
  structuredIssues: [],
  createdAt: DateTime(2020, 1, day),
  updatedAt: DateTime(2020, 1, day),
);

ImportCandidate _candidate(Entry entry, {bool withEvidence = false}) =>
    ImportCandidate(
      entry: entry,
      questions: withEvidence ? [_question('q_${entry.id}', entry.id, 1)] : [],
      answers: withEvidence
          ? [_answer('a_${entry.id}', 'q_${entry.id}', 1)]
          : [],
      hasOriginalId: true,
      incomplete: false,
      legacy: false,
      source: 'test.json',
      index: 1,
    );

ImportPlan _plan(
  List<Entry> entries,
  List<EvidenceQuestion> questions,
  List<EvidenceAnswer> answers,
) => ImportPlan(
  parsed: const ParsedImport(),
  entries: entries,
  questions: questions,
  answers: answers,
  skipped: 0,
  issues: const [],
  incompleteCount: 0,
  legacyCount: 0,
  ignoredLines: 0,
  details: const [],
);

Future<List<String>> _entryIdsOnDisk(_Storage store) async =>
    (jsonDecode(store.values['entries_v1']!) as List)
        .map((row) => (row as Map<String, dynamic>)['id'] as String)
        .toList();

class _Storage implements StorageService {
  final values = <String, String>{};
  final writes = <String, int>{};
  final reads = <String, int>{};
  String? failingKey;
  final failure = StateError('simulated persistence failure');

  @override
  Future<String?> readString(String key) async {
    reads.update(key, (n) => n + 1, ifAbsent: () => 1);
    return values[key];
  }

  @override
  Future<void> writeString(String key, String value) async {
    writes.update(key, (n) => n + 1, ifAbsent: () => 1);
    if (key == failingKey) throw failure;
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}
