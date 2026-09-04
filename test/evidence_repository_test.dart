import 'dart:convert';

import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/storage/storage.dart';
import 'package:daily_asking/evidence/evidence_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalEvidenceRepository 批量读取', () {
    test('100 个 Entry 分组只加载一次 Question 与 Answer 集合', () async {
      final storage = _RecordingStorage({
        'questions_v1': jsonEncode([
          _question(
            id: 'q_late',
            entryId: 'e_42',
            createdAt: DateTime(2026, 8, 25, 10),
          ).toJson(),
          _question(
            id: 'q_early',
            entryId: 'e_42',
            createdAt: DateTime(2026, 8, 25, 8),
          ).toJson(),
          _question(
            id: 'q_other',
            entryId: 'e_other',
            createdAt: DateTime(2026, 8, 25, 9),
          ).toJson(),
        ]),
        'answers_v1': jsonEncode([
          EvidenceAnswer(
            id: 'a_1',
            questionId: 'q_early',
            content: '已验证',
            createdAt: DateTime(2026, 8, 25, 11),
          ).toJson(),
        ]),
      });
      final repository = LocalEvidenceRepository(JsonStore(storage));
      final entryIds = List.generate(100, (index) => 'e_$index');

      final grouped = await repository.questionsByEntryIds(entryIds);
      final allQuestions = await repository.listQuestions();
      final allAnswers = await repository.listAnswers();

      expect(grouped.keys, ['e_42']);
      expect(grouped['e_42']!.map((q) => q.id), ['q_early', 'q_late']);
      expect(allQuestions.map((q) => q.id), [
        'q_early',
        'q_other',
        'q_late',
      ]);
      expect(allAnswers.map((a) => a.id), ['a_1']);
      expect(storage.readCounts, {
        'questions_v1': 1,
        'answers_v1': 1,
      });
    });

    test('空 Entry 集合返回空分组且缓存读取次数保持有界', () async {
      final storage = _RecordingStorage({
        'questions_v1': jsonEncode([
          _question(
            id: 'q_1',
            entryId: 'e_1',
            createdAt: DateTime(2026, 8, 25, 8),
          ).toJson(),
        ]),
        'answers_v1': '[]',
      });
      final repository = LocalEvidenceRepository(JsonStore(storage));

      expect(await repository.questionsByEntryIds(const []), isEmpty);
      expect(await repository.questionsByEntryIds(const []), isEmpty);
      expect(storage.readCounts, {
        'questions_v1': 1,
        'answers_v1': 1,
      });
    });
  });
}

EvidenceQuestion _question({
  required String id,
  required String entryId,
  required DateTime createdAt,
}) {
  return EvidenceQuestion(
    id: id,
    entryId: entryId,
    kind: QuestionKind.result,
    prompt: '结果是什么？',
    reason: '结果为空',
    status: QuestionStatus.pending,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

class _RecordingStorage implements StorageService {
  _RecordingStorage(this.values);

  final Map<String, String> values;
  final Map<String, int> readCounts = {};

  @override
  Future<String?> readString(String key) async {
    readCounts[key] = (readCounts[key] ?? 0) + 1;
    return values[key];
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }
}
