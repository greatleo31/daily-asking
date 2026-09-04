import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/core/models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('应用升级后保留旧版证据、追问、回答和产物', () async {
    final created = DateTime(2026, 8, 20, 9);
    final oldEntry = {
      'id': 'old-entry',
      'date': created.toIso8601String(),
      'task': '升级前保存的证据',
      'context': '旧版本数据',
      'action': '持续记录',
      'result': '已经落盘',
      'blocker': '',
      'tags': <String>['旧数据'],
      'createdAt': created.toIso8601String(),
      'updatedAt': created.toIso8601String(),
    };
    final oldQuestion = {
      'id': 'old-question',
      'entryId': 'old-entry',
      'kind': 'result',
      'prompt': '结果如何验证？',
      'reason': '旧追问',
      'status': 'answered',
      'createdAt': created.toIso8601String(),
      'updatedAt': created.toIso8601String(),
    };
    final oldAnswer = {
      'id': 'old-answer',
      'questionId': 'old-question',
      'content': '升级前的回答',
      'createdAt': created.toIso8601String(),
    };
    final oldArtifact = {
      'id': 'old-artifact',
      'type': 'weekly',
      'content': '# 旧周报\n\n升级前的产物',
      'sourceEntryIds': <String>['old-entry'],
      'risks': <String>[],
      'gaps': <String>[],
      'createdAt': created.toIso8601String(),
      'updatedAt': created.toIso8601String(),
    };

    SharedPreferences.setMockInitialValues({
      'entries_v1': jsonEncode([oldEntry]),
      'questions_v1': jsonEncode([oldQuestion]),
      'answers_v1': jsonEncode([oldAnswer]),
      'artifacts_v1': jsonEncode([oldArtifact]),
    });
    FlutterSecureStorage.setMockInitialValues({});
    final upgraded = await AppState.create();
    await upgraded.bootstrap();

    expect(upgraded.allEntries.single.task, '升级前保存的证据');
    expect(
      (await upgraded.questionsFor('old-entry')).single.id,
      'old-question',
    );
    expect(
      (await upgraded.answersFor('old-question')).single.content,
      '升级前的回答',
    );
    expect(upgraded.artifacts.single.content, '# 旧周报\n\n升级前的产物');

    final now = DateTime(2026, 8, 27, 10);
    await upgraded.updateArtifact(
      Artifact(
        id: 'new-artifact',
        type: ArtifactType.resume,
        content: '# 新简历要点',
        sourceEntryIds: const ['old-entry'],
        risks: const [],
        gaps: const [],
        createdAt: now,
        updatedAt: now,
      ),
    );

    final restarted = await AppState.create();
    await restarted.bootstrap();
    expect(restarted.allEntries.single.id, 'old-entry');
    expect(
      restarted.artifacts.map((artifact) => artifact.id),
      containsAll(['old-artifact', 'new-artifact']),
    );
  });
}
