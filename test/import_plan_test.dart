import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/transfer/import_plan.dart';
import 'package:daily_asking/core/transfer/transfer_schema.dart';

final _date = DateTime(2020, 1, 2, 8, 30);
final _now = DateTime(2026, 9, 17, 12);
Entry _entry(
  String id, {
  String task = '任务',
  List<String> tags = const ['原标签'],
}) => Entry(
  id: id,
  date: _date,
  task: task,
  context: '背景',
  tags: tags,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2026),
);
EvidenceQuestion _question(String id, String entryId) => EvidenceQuestion(
  id: id,
  entryId: entryId,
  kind: QuestionKind.context,
  prompt: '背景？',
  reason: '原因',
  status: QuestionStatus.pending,
  createdAt: DateTime(2021),
  updatedAt: DateTime(2022),
);
EvidenceAnswer _answer(String id, String questionId) => EvidenceAnswer(
  id: id,
  questionId: questionId,
  content: '回答',
  createdAt: DateTime(2023),
);
ImportCandidate _candidate(
  String id, {
  String task = '任务',
  bool hasOriginalId = true,
  bool incomplete = false,
  bool legacy = false,
  String source = 'fixture.json',
  List<String> tags = const ['原标签'],
  List<EvidenceQuestion>? questions,
  List<EvidenceAnswer>? answers,
}) => ImportCandidate(
  entry: _entry(id, task: task, tags: tags),
  questions: questions ?? [_question('q_$id', id)],
  answers: answers ?? [_answer('a_$id', 'q_$id')],
  hasOriginalId: hasOriginalId,
  incomplete: incomplete,
  legacy: legacy,
  source: source,
  index: 1,
);
ImportPlan _plan(
  ParsedImport parsed, {
  List<Entry> entries = const [],
  List<EvidenceQuestion> questions = const [],
  List<EvidenceAnswer> answers = const [],
  DateTime? now,
}) => buildImportPlan(
  parsed,
  existingEntries: entries,
  existingQuestions: questions,
  existingAnswers: answers,
  now: now ?? _now,
);

void main() {
  test(
    'accepted candidates retain the actual winner metadata for duplicate entry IDs',
    () {
      for (final acceptedIncomplete in [false, true]) {
        final rejected = _candidate(
          'same',
          source: 'rejected.json',
          incomplete: !acceptedIncomplete,
          legacy: !acceptedIncomplete,
          questions: [_question('local-q', 'same')],
          answers: [_answer('rejected-a', 'local-q')],
        );
        final accepted = _candidate(
          'same',
          source: 'accepted.json',
          incomplete: acceptedIncomplete,
          legacy: acceptedIncomplete,
        );
        final plan = _plan(
          ParsedImport(candidates: [rejected, accepted]),
          questions: [_question('local-q', 'local-entry')],
        );
        expect(plan.addedCount, 1);
        expect(plan.invalidCount, 1);
        expect(plan.skippedCount, 0);
        expect(plan.acceptedCandidates, [accepted]);
        expect(identical(plan.acceptedCandidates.single, accepted), isTrue);
        expect(plan.acceptedCandidates.single.source, 'accepted.json');
        expect(plan.acceptedCandidates.single.incomplete, acceptedIncomplete);
        expect(plan.acceptedCandidates.single.legacy, acceptedIncomplete);
        expect(plan.incompleteCount, acceptedIncomplete ? 1 : 0);
        expect(plan.legacyCount, acceptedIncomplete ? 1 : 0);
        expect(plan.issues.single.source, 'rejected.json');
      }
    },
  );

  test('legacy fake plans can omit acceptedCandidates', () {
    const plan = ImportPlan(
      parsed: ParsedImport(),
      entries: [],
      questions: [],
      answers: [],
      skipped: 0,
      issues: [],
      incompleteCount: 0,
      legacyCount: 0,
      ignoredLines: 0,
      details: [],
    );
    expect(plan.acceptedCandidates, isEmpty);
  });

  test('entry id collision skips the whole family without overwriting', () {
    final existing = _entry('same', task: '本地修改');
    final before = jsonEncode(existing.toJson());
    final plan = _plan(
      ParsedImport(candidates: [_candidate('same')]),
      entries: [existing],
    );
    expect(plan.addedCount, 0);
    expect(plan.skippedCount, 1);
    expect(plan.entries, isEmpty);
    expect(plan.questions, isEmpty);
    expect(plan.answers, isEmpty);
    expect(plan.invalidCount, 0);
    expect(plan.details.single.disposition, ImportDisposition.skipped);
    expect(jsonEncode(existing.toJson()), before);
  });

  test('no-id fingerprint folds whitespace including full-width spaces', () {
    final existing = _entry('local', task: '  完成\n  数据　迁移 ');
    final plan = _plan(
      ParsedImport(
        candidates: [
          _candidate('generated', task: '完成 数据\t迁移', hasOriginalId: false),
        ],
      ),
      entries: [existing],
    );
    expect(importFingerprint(existing), '2020-01-02|完成 数据 迁移');
    expect(plan.skippedCount, 1);
    expect(plan.entries, isEmpty);
  });

  test('original distinct ids are not deduplicated by their matching text', () {
    final plan = _plan(
      ParsedImport(candidates: [_candidate('new')]),
      entries: [_entry('local')],
    );
    expect(plan.addedCount, 1);
    expect(plan.skippedCount, 0);
  });

  test('fingerprints include calendar date', () {
    final first = _entry('one');
    final other = Entry(
      id: 'two',
      date: _date.add(const Duration(days: 1)),
      task: first.task,
      createdAt: _date,
      updatedAt: _date,
    );
    expect(importFingerprint(first), isNot(importFingerprint(other)));
  });

  test(
    'same-batch duplicates are skipped for ids and missing-id fingerprints',
    () {
      final plan = _plan(
        ParsedImport(
          candidates: [
            _candidate('one', source: 'one.json'),
            _candidate('one', source: 'two.json'),
            _candidate('generated', hasOriginalId: false, source: 'three.md'),
          ],
        ),
      );
      expect(plan.addedCount, 1);
      expect(plan.skippedCount, 2);
      expect(plan.questions.length, 1);
      expect(plan.answers.length, 1);
    },
  );

  test('timestamps normalize only in plan, literal batch tag added once', () {
    final candidate = _candidate('new');
    final parsed = ParsedImport(candidates: [candidate]);
    final before = jsonEncode(candidate.entry.toJson());
    final plan = _plan(parsed);
    final entry = plan.entries.single;
    expect(identical(plan.parsed, parsed), isTrue);
    expect(entry.date, _date);
    expect(entry.createdAt, _date);
    expect(entry.updatedAt, _date);
    expect(entry.tags, ['原标签', '#导入-20260917']);
    expect(plan.questions.single.toJson(), candidate.questions.single.toJson());
    expect(plan.answers.single.toJson(), candidate.answers.single.toJson());
    expect(jsonEncode(candidate.entry.toJson()), before);
    entry.tags.add('仅预览副本');
    plan.questions.single.status = QuestionStatus.skip;
    plan.answers.single.content = '仅预览副本';
    expect(candidate.entry.tags, ['原标签']);
    expect(candidate.questions.single.status, QuestionStatus.pending);
    expect(candidate.answers.single.content, '回答');
    expect(
      _plan(
        ParsedImport(
          candidates: [
            _candidate('tagged', tags: ['#导入-20260917']),
          ],
        ),
      ).entries.single.tags,
      ['#导入-20260917'],
    );
  });

  test(
    'retained parse can be replanned against fresh snapshot and a new day',
    () {
      final parsed = ParsedImport(candidates: [_candidate('new')]);
      final preview = _plan(parsed);
      final fresh = _plan(preview.parsed, entries: [_entry('new')]);
      expect(fresh.skippedCount, 1);
      expect(fresh.addedCount, 0);
      final nextDay = _plan(preview.parsed, now: DateTime(2026, 9, 18));
      expect(nextDay.entries.single.tags, ['原标签', '#导入-20260918']);
    },
  );

  test(
    'existing child id conflicts invalidate incoming family, never overwrite',
    () {
      final candidate = _candidate('new');
      final parsed = ParsedImport(
        candidates: [candidate, _candidate('unrelated')],
      );
      final questionConflict = _plan(
        parsed,
        questions: [_question('q_new', 'local')],
      );
      final answerConflict = _plan(
        parsed,
        answers: [_answer('a_new', 'local-q')],
      );
      for (final plan in [questionConflict, answerConflict]) {
        expect(plan.entries.single.id, 'unrelated');
        expect(plan.invalidCount, 1);
        expect(plan.issues.single.reason, contains('不会覆盖'));
        expect(plan.questions.single.entryId, 'unrelated');
      }
    },
  );

  test(
    'cross-file child collisions reject later group without overwriting',
    () {
      final first = _candidate(
        'one',
        questions: [_question('shared', 'one')],
        answers: [_answer('a1', 'shared')],
      );
      final second = _candidate(
        'two',
        questions: [_question('shared', 'two')],
        answers: [_answer('a2', 'shared')],
      );
      final plan = _plan(
        ParsedImport.combine([
          ParsedImport(candidates: [first]),
          ParsedImport(candidates: [second]),
        ]),
      );
      expect(plan.entries.single.id, 'one');
      expect(plan.questions.single.entryId, 'one');
      expect(plan.answers.single.id, 'a1');
      expect(plan.invalidCount, 1);
    },
  );

  test('rejected group does not reserve ids needed by a later valid group', () {
    final bad = _candidate(
      'bad',
      questions: [_question('shared', 'wrong-owner')],
      answers: [_answer('a', 'shared')],
    );
    final good = _candidate(
      'good',
      questions: [_question('shared', 'good')],
      answers: [_answer('a', 'shared')],
    );
    final plan = _plan(ParsedImport(candidates: [bad, good]));
    expect(plan.entries.single.id, 'good');
    expect(plan.invalidCount, 1);
  });

  test(
    'defensive plan validation refuses orphan linking to local questions',
    () {
      final candidate = _candidate(
        'new',
        questions: [],
        answers: [_answer('a', 'local-q')],
      );
      final plan = _plan(
        ParsedImport(candidates: [candidate]),
        questions: [_question('local-q', 'local')],
      );
      expect(plan.entries, isEmpty);
      expect(plan.invalidCount, 1);
      expect(plan.issues.single.reason, contains('未引用当前记录'));
    },
  );

  test('report totals count accepted incomplete/legacy additions only', () {
    final parsed = ParsedImport(
      candidates: [
        _candidate('new', incomplete: true, legacy: true),
        _candidate('existing', incomplete: true, legacy: true),
        _candidate('full'),
      ],
      issues: const [ImportIssue(source: 'bad.json', index: 3, reason: '字段非法')],
      ignoredLines: 8,
    );
    final plan = _plan(parsed, entries: [_entry('existing')]);
    expect(plan.addedCount, 2);
    expect(plan.skipped, 1);
    expect(plan.skippedCount, 1);
    expect(plan.invalidCount, 1);
    expect(plan.incompleteCount, 1);
    expect(plan.legacyCount, 1);
    expect(plan.ignoredLines, 8);
    expect(plan.details.length, 4);
    expect(
      plan.details
          .where((d) => d.disposition == ImportDisposition.invalid)
          .single
          .reason,
      '字段非法',
    );
    expect(plan.issues.single.source, 'bad.json');
  });

  test('plan retains full detail list; rendering truncation belongs to UI', () {
    final plan = _plan(
      ParsedImport(candidates: List.generate(51, (i) => _candidate('e$i'))),
    );
    expect(plan.addedCount, 51);
    expect(plan.details.length, 51);
  });

  test(
    'separately parsed orphan references cannot link to other imported files',
    () {
      final first = parseTransferJson(
        encodeTransfer(
          TransferData(
            entries: [_entry('e')],
            questions: [_question('q', 'e')],
            answers: [],
          ),
          exportedAt: _now,
          appVersion: 'test',
        ),
        source: 'one.json',
      );
      final second = parseTransferJson(
        encodeTransfer(
          TransferData(
            entries: [_entry('other')],
            questions: [],
            answers: [_answer('a', 'q')],
          ),
          exportedAt: _now,
          appVersion: 'test',
        ),
        source: 'two.json',
      );
      final plan = _plan(ParsedImport.combine([first, second]));
      expect(plan.addedCount, 2);
      expect(plan.answers, isEmpty);
      expect(plan.invalidCount, 1);
      expect(plan.issues.single.source, 'two.json');
    },
  );
}
