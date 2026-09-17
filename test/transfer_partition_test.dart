import 'dart:convert';

import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/transfer/transfer_partition.dart';
import 'package:daily_asking/core/transfer/transfer_schema.dart';
import 'package:flutter_test/flutter_test.dart';

final _date = DateTime(2024, 2, 29);
final _exportedAt = DateTime.utc(2026, 9, 17, 12, 30);
const _version = '测试 "1.2.6"\n版';

Entry _entry(String id, {String task = '完成中文任务🙂'}) => Entry(
  id: id,
  date: _date,
  task: task,
  context: '多行\n背景',
  action: '具体行动',
  result: '结果',
  blocker: '取舍',
  tags: ['含 空格', '#字面标签'],
  createdAt: DateTime.utc(2025, 1, 2, 3, 4, 5, 678),
  updatedAt: DateTime.utc(2026, 2, 3, 4, 5, 6, 789),
);

EvidenceQuestion _question(String id, String entryId) => EvidenceQuestion(
  id: id,
  entryId: entryId,
  kind: QuestionKind.contribution,
  prompt: '个人贡献？\n不要改变',
  reason: '保留原因',
  status: QuestionStatus.later,
  createdAt: _date,
  updatedAt: _exportedAt,
);

EvidenceAnswer _answer(
  String id,
  String questionId, {
  String content = '回答；🙂\n正文',
}) => EvidenceAnswer(
  id: id,
  questionId: questionId,
  content: content,
  createdAt: _exportedAt,
);

List<String> _encode(
  TransferData data, {
  int maxEntries = maxImportEntries,
  int maxBytes = maxTransferFileBytes,
}) => encodeTransferParts(
  data,
  exportedAt: _exportedAt,
  appVersion: _version,
  maxEntries: maxEntries,
  maxBytes: maxBytes,
);

Map<String, dynamic> _decode(String text) =>
    jsonDecode(text) as Map<String, dynamic>;

void _checkPart(
  String text, {
  int maxEntries = maxImportEntries,
  int maxBytes = maxTransferFileBytes,
}) {
  expect(utf8.encode(text).length, lessThanOrEqualTo(maxBytes));
  final decoded = _decode(text);
  expect(
    decoded.keys,
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
  expect(decoded['schema'], transferSchemaV2);
  expect(decoded['schemaVersion'], 2);
  expect(decoded['exportedAt'], _exportedAt.toIso8601String());
  expect(decoded['appVersion'], _version);
  expect((decoded['entries'] as List).length, lessThanOrEqualTo(maxEntries));
  final parsed = parseTransferJson(text, source: 'part.json');
  expect(parsed.issues, isEmpty);
}

void main() {
  test(
    '6000 entries produce two independently importable files in original order',
    () {
      final data = TransferData(
        entries: List.generate(6000, (i) => _entry('e$i')),
        questions: [],
        answers: [],
      );
      final parts = _encode(data);
      expect(parts.length, 2);
      expect((_decode(parts.first)['entries'] as List).length, 5000);
      expect((_decode(parts.last)['entries'] as List).length, 1000);
      for (final part in parts) {
        _checkPart(part);
      }
      final recovered = parts
          .expand((part) => _decode(part)['entries'] as List)
          .toList();
      expect(recovered, data.entries.map((entry) => entry.toJson()).toList());
    },
  );

  test(
    'ordinary data remains one file, equivalent to the existing v2 exporter',
    () {
      final data = TransferData(
        entries: [_entry('e')],
        questions: [_question('q', 'e')],
        answers: [_answer('a', 'q')],
      );
      final parts = _encode(data);
      expect(parts.length, 1);
      expect(
        _decode(parts.single),
        jsonDecode(
          encodeTransfer(data, exportedAt: _exportedAt, appVersion: _version),
        ),
      );
      _checkPart(parts.single);
    },
  );

  test(
    'exact non-ASCII UTF-8 byte boundary includes metadata, commas and escaping',
    () {
      final data = TransferData(
        entries: [
          _entry('e1', task: '中文🙂\n"引号"\\'),
          _entry('e2', task: '中文🙂\n"引号"\\'),
        ],
        questions: [_question('q1', 'e1'), _question('q2', 'e2')],
        answers: [_answer('a1', 'q1'), _answer('a2', 'q2')],
      );
      final whole = _encode(data).single;
      final exactBytes = utf8.encode(whole).length;
      expect(exactBytes, greaterThan(whole.length));
      expect(_encode(data, maxBytes: exactBytes), [whole]);
      final split = _encode(data, maxBytes: exactBytes - 1);
      expect(split.length, 2);
      for (final part in split) {
        _checkPart(part, maxBytes: exactBytes - 1);
        final parsed = parseTransferJson(part, source: 'boundary.json');
        expect(parsed.candidates.single.questions.length, 1);
        expect(parsed.candidates.single.answers.length, 1);
      }
      final singletonBytes = utf8.encode(split.first).length;
      final firstOnly = TransferData(
        entries: [data.entries.first],
        questions: [data.questions.first],
        answers: [data.answers.first],
      );
      expect(_encode(firstOnly, maxBytes: singletonBytes), [split.first]);
      expect(
        () => _encode(firstOnly, maxBytes: singletonBytes - 1),
        throwsA(
          isA<TransferPartitionException>().having(
            (e) => e.message,
            'message',
            contains('单条记录及其追问回答超过'),
          ),
        ),
      );
    },
  );

  test(
    'multiple questions and answers stay atomic and roundtrip every model field',
    () {
      final entries = List.generate(5, (i) => _entry('e$i'));
      final questions = <EvidenceQuestion>[
        for (var i = 4; i >= 0; i--) _question('q${i}a', 'e$i'),
        for (var i = 0; i < 5; i++) _question('q${i}b', 'e$i'),
      ];
      final answers = <EvidenceAnswer>[
        for (final question in questions.reversed)
          _answer('a_${question.id}_1', question.id),
        for (final question in questions)
          _answer('a_${question.id}_2', question.id),
      ];
      final data = TransferData(
        entries: entries,
        questions: questions,
        answers: answers,
      );
      final parts = _encode(data, maxEntries: 2);
      expect(parts.length, 3);
      final recovered = <ImportCandidate>[];
      for (final part in parts) {
        _checkPart(part, maxEntries: 2);
        final decoded = _decode(part);
        final partEntries = (decoded['entries'] as List)
            .map((e) => e['id'])
            .toSet();
        final expectedQuestions = questions
            .where((q) => partEntries.contains(q.entryId))
            .toList();
        final partQuestions = expectedQuestions.map((q) => q.id).toSet();
        // Relative order within each part is unchanged, even with interleaving.
        expect(
          decoded['questions'],
          expectedQuestions.map((q) => q.toJson()).toList(),
        );
        expect(
          decoded['answers'],
          answers
              .where((a) => partQuestions.contains(a.questionId))
              .map((a) => a.toJson())
              .toList(),
        );
        final parsed = parseTransferJson(part, source: 'part.json');
        recovered.addAll(parsed.candidates);
        for (final candidate in parsed.candidates) {
          expect(candidate.questions.length, 2);
          expect(candidate.answers.length, 4);
          expect(
            candidate.entry.toJson(),
            entries.singleWhere((e) => e.id == candidate.entry.id).toJson(),
          );
          for (final question in candidate.questions) {
            expect(
              question.toJson(),
              questions.singleWhere((q) => q.id == question.id).toJson(),
            );
          }
          for (final answer in candidate.answers) {
            expect(
              answer.toJson(),
              answers.singleWhere((a) => a.id == answer.id).toJson(),
            );
          }
        }
      }
      expect(recovered.map((c) => c.entry.id), entries.map((e) => e.id));
      expect(recovered.expand((c) => c.questions).length, questions.length);
      expect(recovered.expand((c) => c.answers).length, answers.length);
    },
  );

  test(
    'empty data produces one valid empty file, even at the exact byte cap',
    () {
      const data = TransferData(entries: [], questions: [], answers: []);
      final parts = _encode(data);
      expect(parts.length, 1);
      _checkPart(parts.single);
      expect(_decode(parts.single)['entries'], isEmpty);
      expect(_decode(parts.single)['questions'], isEmpty);
      expect(_decode(parts.single)['answers'], isEmpty);
      final bytes = utf8.encode(parts.single).length;
      expect(_encode(data, maxBytes: bytes), parts);
      expect(
        () => _encode(data, maxBytes: bytes - 1),
        throwsA(
          isA<TransferPartitionException>().having(
            (e) => e.message,
            'message',
            contains('元信息'),
          ),
        ),
      );
    },
  );

  test(
    'one oversized group fails explicitly, never returns earlier partial files',
    () {
      final data = TransferData(
        entries: [_entry('first'), _entry('oversized')],
        questions: [_question('q', 'oversized')],
        answers: [
          _answer(
            'a',
            'q',
            content: List.filled(maxTransferFileBytes ~/ 3, '中').join(),
          ),
        ],
      );
      expect(
        () => _encode(data, maxEntries: 1),
        throwsA(
          isA<TransferPartitionException>().having(
            (e) => e.message,
            'message',
            '单条记录及其追问回答超过 10 MB，无法分片导出',
          ),
        ),
      );
    },
  );

  test('orphan business rows fail instead of being silently dropped', () {
    for (final data in [
      TransferData(
        entries: [],
        questions: [_question('q', 'missing')],
        answers: [],
      ),
      TransferData(
        entries: [_entry('e')],
        questions: [],
        answers: [_answer('a', 'missing')],
      ),
      TransferData(
        entries: [_entry('e')],
        questions: [_question('q', 'missing')],
        answers: [_answer('a', 'q')],
      ),
    ]) {
      expect(
        () => _encode(data),
        throwsA(
          isA<TransferPartitionException>().having(
            (e) => e.message,
            'message',
            contains('未关联'),
          ),
        ),
      );
    }
  });

  test(
    'duplicate or empty IDs fail safely instead of changing reference ownership',
    () {
      for (final data in [
        TransferData(
          entries: [_entry('e'), _entry('e')],
          questions: [],
          answers: [],
        ),
        TransferData(
          entries: [_entry('e')],
          questions: [_question('q', 'e'), _question('q', 'e')],
          answers: [],
        ),
        TransferData(
          entries: [_entry('e')],
          questions: [_question('q', 'e')],
          answers: [_answer('a', 'q'), _answer('a', 'q')],
        ),
        TransferData(entries: [_entry(' ')], questions: [], answers: []),
      ]) {
        expect(() => _encode(data), throwsA(isA<TransferPartitionException>()));
      }
    },
  );

  test('source models, timestamps and list order are not mutated', () {
    final data = TransferData(
      entries: [_entry('e1'), _entry('e2')],
      questions: [_question('q2', 'e2'), _question('q1', 'e1')],
      answers: [_answer('a1', 'q1'), _answer('a2', 'q2')],
    );
    final before = encodeTransfer(
      data,
      exportedAt: _exportedAt,
      appVersion: _version,
    );
    final parts = _encode(data, maxEntries: 1);
    expect(parts.length, 2);
    expect(
      encodeTransfer(data, exportedAt: _exportedAt, appVersion: _version),
      before,
    );
  });

  test('custom limits cannot disable the importers hard limits', () {
    const data = TransferData(entries: [], questions: [], answers: []);
    for (final cap in [0, -1, 5001]) {
      expect(
        () => _encode(data, maxEntries: cap),
        throwsA(isA<TransferPartitionException>()),
      );
    }
    for (final cap in [0, -1, maxTransferFileBytes + 1]) {
      expect(
        () => _encode(data, maxBytes: cap),
        throwsA(isA<TransferPartitionException>()),
      );
    }
  });
}
