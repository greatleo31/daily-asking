import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/transfer/transfer_schema.dart';

final _date = DateTime(2024, 2, 29);
final _created = DateTime.utc(2024, 3, 1, 12, 34, 56, 789);

Entry _entry(String id) => Entry(
  id: id,
  date: _date,
  task: '任务\n第二行',
  context: '背景',
  action: '行动',
  result: '结果',
  blocker: '取舍',
  tags: ['含 空格', '#标签'],
  createdAt: _created,
  updatedAt: _created.add(const Duration(days: 2)),
);
EvidenceQuestion _question(String id, String entryId) => EvidenceQuestion(
  id: id,
  entryId: entryId,
  kind: QuestionKind.contribution,
  prompt: '贡献？',
  reason: '保留原因',
  status: QuestionStatus.later,
  createdAt: _created,
  updatedAt: _created.add(const Duration(hours: 2)),
);
EvidenceAnswer _answer(String id, String questionId) => EvidenceAnswer(
  id: id,
  questionId: questionId,
  content: '答案\n保留；分号',
  createdAt: _created,
);
Map<String, dynamic> _document() => {
  'schema': transferSchemaV2,
  'schemaVersion': 2,
  'entries': [_entry('e1').toJson(), _entry('e2').toJson()],
  'questions': [_question('q1', 'e1').toJson()],
  'answers': [_answer('a1', 'q1').toJson()],
};
ParsedImport _parse(Map<String, dynamic> doc) =>
    parseTransferJson(jsonEncode(doc), source: 'fixture.json');

void main() {
  test('date range boundaries do not escape row validation', () {
    for (final date in [
      '-271821-04-19T23:00:00-01:00',
      '275760-09-13T01:00:00+01:00',
    ]) {
      final parsed = _parse({
        'schema': transferSchemaV1,
        'entries': [
          {'date': date, 'task': '极限日期'},
        ],
      });
      expect(parsed.issues, isEmpty, reason: date);
      expect(parsed.candidates.single.entry.date, DateTime.parse(date));
    }
    for (final date in [
      '275760-09-14T00:00:00+24:00',
      '2023-02-29',
      '1900-02-29',
      '2024-00-10',
      '2024-12-32',
    ]) {
      final parsed = _parse({
        'schema': transferSchemaV1,
        'entries': [
          {'date': date, 'task': '非法日期'},
        ],
      });
      expect(parsed.candidates, isEmpty, reason: date);
      expect(parsed.issues.single.index, 1);
    }
  });

  test(
    'v2 exports exactly seven keys and preserves all model fields on parse',
    () {
      final data = TransferData(
        entries: [_entry('e1')],
        questions: [_question('q1', 'e1')],
        answers: [_answer('a1', 'q1'), _answer('a2', 'q1')],
      );
      final encoded = encodeTransfer(
        data,
        exportedAt: _created,
        appVersion: '1.2.6',
      );
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      expect(
        json.keys,
        unorderedEquals([
          'schema',
          'schemaVersion',
          'exportedAt',
          'appVersion',
          'entries',
          'questions',
          'answers',
        ]),
      );
      expect(json['exportedAt'], _created.toIso8601String());
      expect(json['appVersion'], '1.2.6');
      final parsed = parseTransferJson(encoded, source: 'backup.json');
      expect(parsed.issues, isEmpty);
      final candidate = parsed.candidates.single;
      expect(candidate.entry.toJson(), data.entries.single.toJson());
      expect(
        candidate.questions.single.toJson(),
        data.questions.single.toJson(),
      );
      expect(
        candidate.answers.map((a) => a.toJson()),
        data.answers.map((a) => a.toJson()),
      );
      expect(candidate.hasOriginalId, isTrue);
      expect(candidate.incomplete, isFalse);
      expect(candidate.legacy, isFalse);
    },
  );

  test('empty export is a valid snapshot', () {
    final encoded = encodeTransfer(
      const TransferData(entries: [], questions: [], answers: []),
      exportedAt: _created,
      appVersion: 'test',
    );
    final parsed = parseTransferJson(encoded, source: 'empty.json');
    expect(parsed.candidates, isEmpty);
    expect(parsed.issues, isEmpty);
  });

  test('future and unknown schemas reject the whole file', () {
    for (final edit in [
      {'schema': 'daily_asking.export.v99'},
      {'schemaVersion': 3},
    ]) {
      final parsed = _parse(_document()..addAll(edit));
      expect(parsed.candidates, isEmpty);
      expect(parsed.issues.single.index, 0);
      expect(parsed.issues.single.reason, contains('请先升级'));
    }
  });

  test('malformed JSON and envelopes return file issues, not exceptions', () {
    for (final text in ['{', '[]', 'null', '123']) {
      expect(
        parseTransferJson(text, source: 'bad.json').issues.single.index,
        0,
      );
    }
    for (final edit in [
      {'schemaVersion': '2'},
      {'schemaVersion': 2.0},
      {'entries': null},
      {'questions': {}},
      {'answers': null},
    ]) {
      final parsed = _parse(_document()..addAll(edit));
      expect(parsed.candidates, isEmpty);
      expect(parsed.issues.single.index, 0);
    }
  });

  test('required fields and typed optional fields are validated per row', () {
    for (final key in ['id', 'date', 'task', 'createdAt', 'updatedAt']) {
      final doc = _document();
      (doc['entries'][0] as Map).remove(key);
      final parsed = _parse(doc);
      expect(parsed.candidates.single.entry.id, 'e2', reason: key);
      expect(
        parsed.issues.any(
          (issue) => issue.index == 1 && issue.reason.contains(key),
        ),
        isTrue,
        reason: key,
      );
    }
    for (final edit in [
      {
        'tags': ['valid', 1],
      },
      {'context': 7},
      {'task': null},
      {'id': ' '},
      {'date': '2024-02-30'},
      {'createdAt': '2024-02-29T24:00:00'},
    ]) {
      final doc = _document();
      (doc['entries'][0] as Map).addAll(edit);
      final parsed = _parse(doc);
      expect(parsed.candidates.single.entry.id, 'e2');
      expect(parsed.issues.any((issue) => issue.index == 1), isTrue);
    }
  });

  test('non-object rows are isolated', () {
    final doc = _document();
    doc['entries'] = [null, _entry('e2').toJson()];
    doc['questions'] = [];
    doc['answers'] = [];
    final parsed = _parse(doc);
    expect(parsed.candidates.single.entry.id, 'e2');
    expect(parsed.issues.single.reason, contains('必须为对象'));
  });

  test('invalid child enums or fields fail only the owning entry', () {
    for (final edit in [
      {'kind': 'future'},
      {'status': 'future'},
      {'prompt': 1},
      {'reason': null},
      {'createdAt': 'yesterday'},
      {'id': ''},
    ]) {
      final doc = _document();
      (doc['questions'][0] as Map).addAll(edit);
      final parsed = _parse(doc);
      expect(parsed.candidates.single.entry.id, 'e2');
      expect(
        parsed.issues.any(
          (issue) => issue.index == 1 && issue.reason.contains('questions[1]'),
        ),
        isTrue,
      );
    }
    final doc = _document();
    doc['answers'][0]['content'] = 2;
    final parsed = _parse(doc);
    expect(parsed.candidates.single.entry.id, 'e2');
    expect(parsed.issues.single.reason, contains('answers[1]'));
  });

  test('orphan questions/answers are explicit and cannot attach elsewhere', () {
    final doc = _document();
    doc['questions'].add(
      _question('orphan', 'not-in-file').toJson()..['kind'] = 'invalid',
    );
    doc['answers'].add(_answer('orphan-answer', 'orphan').toJson());
    doc['answers'].add(_answer('unknown-question', 'local-q').toJson());
    final parsed = _parse(doc);
    expect(parsed.candidates.length, 2);
    expect(parsed.issues.length, 3);
    expect(parsed.issues.every((i) => i.reason.contains('孤立')), isTrue);
    expect(parsed.issues.first.reason, contains('未知 kind'));
    expect(parsed.candidates.first.questions.single.id, 'q1');
    expect(parsed.candidates.first.answers.single.id, 'a1');
  });

  test('duplicate child IDs fail both owners, not last-write-wins', () {
    final doc = _document();
    doc['questions'].add(_question('q1', 'e2').toJson());
    final parsed = _parse(doc);
    expect(parsed.candidates, isEmpty);
    expect(
      parsed.issues.where((i) => i.reason.contains('questions 的 id 重复')).length,
      2,
    );
    expect(parsed.issues.any((i) => i.reason.contains('answers[1]')), isTrue);

    final answers = _document();
    answers['questions'].add(_question('q2', 'e2').toJson());
    answers['answers'].add(_answer('a1', 'q2').toJson());
    expect(_parse(answers).candidates, isEmpty);
    expect(_parse(answers).issues.length, 2);
  });

  test('duplicate entry IDs cannot ambiguously link children', () {
    final doc = _document();
    doc['entries'][1]['id'] = 'e1';
    final parsed = _parse(doc);
    expect(parsed.candidates, isEmpty);
    expect(parsed.issues.where((i) => i.reason.contains('记录 id 重复')).length, 2);
  });

  test(
    'legacy missing timestamps fall back to date and absent id is generated',
    () {
      final original = _entry('legacy').toJson()
        ..remove('createdAt')
        ..remove('updatedAt');
      final noId = Map<String, dynamic>.of(original)..remove('id');
      final parsed = _parse({
        'schema': transferSchemaV1,
        'entries': [original, noId],
      });
      expect(parsed.issues, isEmpty);
      expect(parsed.candidates.length, 2);
      expect(parsed.candidates.first.entry.createdAt, _date);
      expect(parsed.candidates.first.entry.updatedAt, _date);
      expect(parsed.candidates.first.hasOriginalId, isTrue);
      expect(parsed.candidates.last.hasOriginalId, isFalse);
      expect(parsed.candidates.last.entry.id, startsWith('e_'));
      expect(parsed.candidates.every((c) => c.legacy && c.incomplete), isTrue);
    },
  );

  test(
    'limit includes invalid rows and rejects the entire file above 5000',
    () {
      final doc = _document()..['entries'] = List.filled(5001, null);
      final parsed = _parse(doc);
      expect(parsed.candidates, isEmpty);
      expect(parsed.issues.single.reason, '文件包含超过 5000 条记录');
      final allowed = _parse({
        'schema': transferSchemaV1,
        'entries': List.generate(5000, (i) => _entry('e$i').toJson()),
      });
      expect(allowed.candidates.length, 5000);
      expect(allowed.issues, isEmpty);
    },
  );

  test(
    'BOM accepted and combined files retain source/index and ignored counts',
    () {
      final parsed = parseTransferJson(
        '\uFEFF${jsonEncode(_document())}',
        source: 'bom.json',
      );
      expect(parsed.issues, isEmpty);
      final combined = ParsedImport.combine([
        parsed,
        const ParsedImport(
          issues: [ImportIssue(source: 'other.md', index: 0, reason: '坏文件')],
          ignoredLines: 4,
        ),
      ]);
      expect(combined.candidates.length, 2);
      expect(combined.candidates.first.source, 'bom.json');
      expect(combined.issues.single.source, 'other.md');
      expect(combined.ignoredLines, 4);
    },
  );
}
