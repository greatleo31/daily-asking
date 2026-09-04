import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/evidence/evidence_repository.dart';
import 'package:daily_asking/evidence/evidence_service.dart';
import 'package:daily_asking/journal/journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvidenceService 回答追问', () {
    test('五种问题分别回填对应字段且贡献回答不改叙事字段', () async {
      final entry = _entry(
        id: 'e_1',
        task: '完成发布',
        context: '',
        action: '已有行动 ',
        result: '已有结果 ',
        blocker: '',
      );
      final entries = _MemoryEntryRepository([entry]);
      final evidence = _RecordingEvidenceRepository(
        questions: [
          _question('q_result', entry.id, QuestionKind.result),
          _question('q_context', entry.id, QuestionKind.context),
          _question('q_action', entry.id, QuestionKind.action),
          _question('q_blocker', entry.id, QuestionKind.blocker),
          _question('q_contribution', entry.id, QuestionKind.contribution),
        ],
      );
      final service = EvidenceService(entries, evidence);

      await service.answerQuestion('q_result', ' 新结果 ');
      await service.answerQuestion('q_context', ' 补充背景 ');
      await service.answerQuestion('q_action', ' 补充行动 ');
      await service.answerQuestion('q_blocker', ' 补充难点 ');
      await service.answerQuestion('q_contribution', ' 我独立完成 ');

      final saved = await entries.find(entry.id);
      expect(saved, isNotNull);
      expect(saved!.result, '已有结果；新结果');
      expect(saved.context, '补充背景');
      expect(saved.action, '已有行动；补充行动');
      expect(saved.blocker, '补充难点');
      expect(evidence.answers.map((a) => a.content), [
        '新结果',
        '补充背景',
        '补充行动',
        '补充难点',
        '我独立完成',
      ]);
      // 回答后可能立刻再生成下一问；仅断言原 5 条均已回答。
      final answeredIds = {
        'q_result',
        'q_context',
        'q_action',
        'q_blocker',
        'q_contribution',
      };
      expect(
        evidence.questions
            .where((q) => answeredIds.contains(q.id))
            .map((q) => q.status),
        everyElement(QuestionStatus.answered),
      );
    });

    test('空白回答仍保存空内容并标记已回答但不改原字段', () async {
      final entry = _entry(id: 'e_1', task: '完成发布', result: '原结果');
      final entries = _MemoryEntryRepository([entry]);
      final evidence = _RecordingEvidenceRepository(
        questions: [_question('q_1', entry.id, QuestionKind.result)],
      );
      final service = EvidenceService(entries, evidence);

      await service.answerQuestion('q_1', '   ');

      final saved = await entries.find(entry.id);
      expect(saved!.result, '原结果');
      expect(evidence.answers.single.content, '');
      expect(
        evidence.questions.firstWhere((q) => q.id == 'q_1').status,
        QuestionStatus.answered,
      );
    });

    test('未知 questionId 不写 Answer、Question 或 Entry', () async {
      final entries = _MemoryEntryRepository([
        _entry(id: 'e_1', task: '完成发布'),
      ]);
      final evidence = _RecordingEvidenceRepository(
        questions: [_question('q_known', 'e_1', QuestionKind.result)],
      );
      final service = EvidenceService(entries, evidence);

      await service.answerQuestion('q_missing', '不会落库');

      expect(evidence.listQuestionsCalls, 1);
      expect(evidence.saveAnswerCalls, 0);
      expect(evidence.saveQuestionCalls, 0);
      expect(entries.findCalls, 0);
      expect(entries.saveCalls, 0);
      expect(evidence.answers, isEmpty);
      expect(evidence.questions.single.status, QuestionStatus.pending);
    });
  });

  group('EvidenceService 连续追问编排', () {
    test('空记录首问为 context；skip 立刻返回 action；existing 含 skip context',
        () async {
      final entry = _entry(id: 'e_chain', task: '一件小事');
      final entries = _MemoryEntryRepository([]);
      final evidence = _RecordingEvidenceRepository();
      final service = EvidenceService(entries, evidence);

      final first = await service.saveEntryAndGenerateQuestion(entry);
      expect(first, isNotNull);
      expect(first!.kind, QuestionKind.context);

      final next = await service.setQuestionStatus(first.id, QuestionStatus.skip);
      expect(next, isNotNull);
      expect(next!.kind, QuestionKind.action);

      final existing = await service.questionsForEntry(entry.id);
      expect(
        existing.any((q) =>
            q.kind == QuestionKind.context && q.status == QuestionStatus.skip),
        isTrue,
      );
      expect(
        existing.any((q) =>
            q.kind == QuestionKind.action &&
            q.status == QuestionStatus.pending),
        isTrue,
      );
    });

    test('连续 skip 直至无剩余返回 null', () async {
      final entry = _entry(id: 'e_all', task: '一件小事');
      final entries = _MemoryEntryRepository([]);
      final evidence = _RecordingEvidenceRepository();
      final service = EvidenceService(entries, evidence);

      var current = await service.saveEntryAndGenerateQuestion(entry);
      expect(current, isNotNull);

      final kinds = <QuestionKind>[];
      while (current != null) {
        kinds.add(current.kind);
        current =
            await service.setQuestionStatus(current.id, QuestionStatus.skip);
      }

      expect(kinds, [
        QuestionKind.context,
        QuestionKind.action,
        QuestionKind.result,
        QuestionKind.blocker,
        QuestionKind.contribution,
      ]);
      expect(current, isNull);
    });

    test('回答路径在字段仍空时也产出下一问', () async {
      final entry = _entry(id: 'e_ans', task: '一件小事');
      final entries = _MemoryEntryRepository([]);
      final evidence = _RecordingEvidenceRepository();
      final service = EvidenceService(entries, evidence);

      final first = await service.saveEntryAndGenerateQuestion(entry);
      expect(first!.kind, QuestionKind.context);

      // 回答 context 会回填背景，下一问应为 action（其余字段仍空）。
      final next = await service.answerQuestion(first.id, '客户现场培训');
      expect(next, isNotNull);
      expect(next!.kind, QuestionKind.action);

      final saved = await entries.find(entry.id);
      expect(saved!.context, '客户现场培训');
    });

    test('setQuestionStatus(later) 不触发连续下一问', () async {
      final entry = _entry(id: 'e_later', task: '一件小事');
      final entries = _MemoryEntryRepository([]);
      final evidence = _RecordingEvidenceRepository();
      final service = EvidenceService(entries, evidence);

      final first = await service.saveEntryAndGenerateQuestion(entry);
      final next =
          await service.setQuestionStatus(first!.id, QuestionStatus.later);
      expect(next, isNull);
      expect(evidence.questions.where((q) => q.status == QuestionStatus.pending),
          isEmpty);
    });
  });
  group('EvidenceService 级联与聚合', () {
    test('删除一个 Entry 只清理它的问题与答案', () async {
      final entries = _MemoryEntryRepository([
        _entry(id: 'e_delete', task: '待删除'),
        _entry(id: 'e_keep', task: '保留'),
      ]);
      final evidence = _RecordingEvidenceRepository(
        questions: [
          _question('q_delete', 'e_delete', QuestionKind.result),
          _question('q_keep', 'e_keep', QuestionKind.context),
        ],
        answers: [
          _answer('a_delete', 'q_delete', '删除回答'),
          _answer('a_keep', 'q_keep', '保留回答'),
        ],
      );
      final service = EvidenceService(entries, evidence);

      await service.deleteEntryCascade('e_delete');

      expect(entries.items.map((e) => e.id), ['e_keep']);
      expect(evidence.questions.map((q) => q.id), ['q_keep']);
      expect(evidence.answers.map((a) => a.id), ['a_keep']);
      expect(evidence.deletedEntryIds, ['e_delete']);
    });

    test('刷新 50 个 Entry 只批量读取一次 Question 且不逐 Entry 查询', () async {
      final entries = List.generate(
        50,
        (index) => _entry(id: 'e_$index', task: '任务 $index'),
      );
      final evidence = _RecordingEvidenceRepository(
        questions: [
          _question('q_later', 'e_20', QuestionKind.result,
              status: QuestionStatus.later,
              createdAt: DateTime(2026, 8, 25, 10)),
          _question('q_pending', 'e_20', QuestionKind.context,
              createdAt: DateTime(2026, 8, 25, 8)),
          _question('q_answered', 'e_21', QuestionKind.contribution,
              status: QuestionStatus.answered),
        ],
      );
      final service = EvidenceService(_MemoryEntryRepository(entries), evidence);

      final view = await service.refreshView(entries);

      expect(evidence.listQuestionsCalls, 1);
      expect(evidence.questionsForCalls, 0);
      expect(view.metrics.totalEntries, 50);
      expect(view.metrics.openQuestionCount, 2);
      expect(view.metrics.contributionCount, 1);
      expect(view.openByEntry.length, 50);
      expect(
        view.openByEntry['e_20']!.map((q) => q.id),
        ['q_pending', 'q_later'],
      );
      expect(view.openByEntry['e_0'], isEmpty);
    });

    test('metrics 保持旧实现语义：指标计数包含孤立问题', () async {
      final today = DateTime.now();
      final entries = [
        _entry(
          id: 'e_1',
          task: '上线功能',
          context: '客户需求',
          action: '实现并验证',
          result: '已上线',
          blocker: '时间紧',
          tags: const ['交付', '客户'],
          date: today,
        ),
        _entry(
          id: 'e_2',
          task: '复盘',
          tags: const ['交付'],
          date: today,
        ),
      ];
      final evidence = _RecordingEvidenceRepository(
        questions: [
          _question('q_open', 'e_1', QuestionKind.result),
          _question('q_later', 'e_2', QuestionKind.context,
              status: QuestionStatus.later),
          _question('q_contribution', 'e_2', QuestionKind.contribution,
              status: QuestionStatus.answered),
          _question('q_orphan_open', 'e_missing', QuestionKind.result),
          _question(
            'q_orphan_contribution',
            'e_missing',
            QuestionKind.contribution,
            status: QuestionStatus.answered,
          ),
        ],
      );
      final repository = _MemoryEntryRepository(entries);
      final service = EvidenceService(repository, evidence);

      final metrics = await service.metrics();

      expect(repository.listCalls, 1);
      expect(evidence.listQuestionsCalls, 1);
      expect(evidence.questionsForCalls, 0);
      expect(metrics.totalEntries, 2);
      expect(metrics.averageCompleteness, 60);
      expect(metrics.tagCounts, {'交付': 2, '客户': 1});
      expect(metrics.openQuestionCount, 3);
      expect(metrics.contributionCount, 2);
      expect(metrics.recentFreqByDay.values.fold<int>(0, (a, b) => a + b), 2);
    });
  });
}

Entry _entry({
  required String id,
  required String task,
  String context = '',
  String action = '',
  String result = '',
  String blocker = '',
  List<String> tags = const [],
  DateTime? date,
}) {
  final timestamp = DateTime(2026, 8, 25, 9);
  return Entry(
    id: id,
    date: date ?? timestamp,
    task: task,
    context: context,
    action: action,
    result: result,
    blocker: blocker,
    tags: tags,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

EvidenceQuestion _question(
  String id,
  String entryId,
  QuestionKind kind, {
  QuestionStatus status = QuestionStatus.pending,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime(2026, 8, 25, 9);
  return EvidenceQuestion(
    id: id,
    entryId: entryId,
    kind: kind,
    prompt: '${kind.label}是什么？',
    reason: '${kind.field}为空',
    status: status,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

EvidenceAnswer _answer(String id, String questionId, String content) {
  return EvidenceAnswer(
    id: id,
    questionId: questionId,
    content: content,
    createdAt: DateTime(2026, 8, 25, 10),
  );
}

class _MemoryEntryRepository implements EntryRepository {
  _MemoryEntryRepository(List<Entry> entries)
      : items = entries.map((entry) => entry.copy()).toList();

  final List<Entry> items;
  int listCalls = 0;
  int findCalls = 0;
  int saveCalls = 0;

  @override
  Future<void> delete(String id) async {
    items.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<Entry?> find(String id) async {
    findCalls++;
    for (final entry in items) {
      if (entry.id == id) return entry.copy();
    }
    return null;
  }

  @override
  Future<List<Entry>> list() async {
    listCalls++;
    return items.map((entry) => entry.copy()).toList();
  }

  @override
  Future<void> save(Entry entry) async {
    saveCalls++;
    final index = items.indexWhere((candidate) => candidate.id == entry.id);
    if (index == -1) {
      items.add(entry.copy());
    } else {
      items[index] = entry.copy();
    }
  }
}

class _RecordingEvidenceRepository implements EvidenceRepository {
  _RecordingEvidenceRepository({
    List<EvidenceQuestion> questions = const [],
    List<EvidenceAnswer> answers = const [],
  })  : questions = questions.map(_copyQuestion).toList(),
        answers = answers.map(_copyAnswer).toList();

  final List<EvidenceQuestion> questions;
  final List<EvidenceAnswer> answers;
  final List<String> deletedEntryIds = [];
  int listQuestionsCalls = 0;
  int questionsForCalls = 0;
  int saveAnswerCalls = 0;
  int saveQuestionCalls = 0;

  @override
  Future<List<EvidenceAnswer>> answersFor(String questionId) async => answers
      .where((answer) => answer.questionId == questionId)
      .map(_copyAnswer)
      .toList();

  @override
  Future<void> deleteForEntry(String entryId) async {
    deletedEntryIds.add(entryId);
    final questionIds = questions
        .where((question) => question.entryId == entryId)
        .map((question) => question.id)
        .toSet();
    questions.removeWhere((question) => question.entryId == entryId);
    answers.removeWhere((answer) => questionIds.contains(answer.questionId));
  }

  @override
  Future<List<EvidenceAnswer>> listAnswers() async =>
      answers.map(_copyAnswer).toList();

  @override
  Future<List<EvidenceQuestion>> listQuestions() async {
    listQuestionsCalls++;
    return questions.map(_copyQuestion).toList();
  }

  @override
  Future<List<EvidenceQuestion>> openQuestionsFor(String entryId) async =>
      questions
          .where((question) =>
              question.entryId == entryId &&
              (question.status == QuestionStatus.pending ||
                  question.status == QuestionStatus.later))
          .map(_copyQuestion)
          .toList();

  @override
  Future<Map<String, List<EvidenceQuestion>>> questionsByEntryIds(
    Iterable<String> entryIds,
  ) async {
    final ids = entryIds.toSet();
    final grouped = <String, List<EvidenceQuestion>>{};
    for (final question in questions) {
      if (!ids.contains(question.entryId)) continue;
      grouped.putIfAbsent(question.entryId, () => []).add(_copyQuestion(question));
    }
    return grouped;
  }

  @override
  Future<List<EvidenceQuestion>> questionsFor(String entryId) async {
    questionsForCalls++;
    return questions
        .where((question) => question.entryId == entryId)
        .map(_copyQuestion)
        .toList();
  }

  @override
  Future<void> saveAnswer(EvidenceAnswer answer) async {
    saveAnswerCalls++;
    final index = answers.indexWhere((candidate) => candidate.id == answer.id);
    if (index == -1) {
      answers.add(_copyAnswer(answer));
    } else {
      answers[index] = _copyAnswer(answer);
    }
  }

  @override
  Future<void> saveQuestion(EvidenceQuestion question) async {
    saveQuestionCalls++;
    final index = questions.indexWhere((candidate) => candidate.id == question.id);
    if (index == -1) {
      questions.add(_copyQuestion(question));
    } else {
      questions[index] = _copyQuestion(question);
    }
  }
}

EvidenceQuestion _copyQuestion(EvidenceQuestion question) =>
    EvidenceQuestion.fromJson(question.toJson());

EvidenceAnswer _copyAnswer(EvidenceAnswer answer) =>
    EvidenceAnswer.fromJson(answer.toJson());
