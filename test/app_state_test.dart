import 'dart:convert';

import 'package:daily_asking/app/app_state.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/settings/settings_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppState 定向刷新边界', () {
    test('主题更新保持证据、产物和 LLM 快照引用稳定', () async {
      final state = await _createBootstrappedState();
      final entriesBefore = state.allEntries;
      final todayBefore = state.todayEntries;
      final metricsBefore = state.metrics;
      final artifactsBefore = state.artifacts;
      final llmBefore = state.llmSettings;

      await state.setTheme(ThemeModePreference.dark);

      expect(state.theme, ThemeModePreference.dark);
      expect(state.allEntries, same(entriesBefore));
      expect(state.todayEntries, same(todayBefore));
      expect(state.metrics, same(metricsBefore));
      expect(state.artifacts, same(artifactsBefore));
      expect(state.llmSettings, same(llmBefore));
    });

    test('产物更新只替换产物快照并保持证据与设置快照稳定', () async {
      final state = await _createBootstrappedState();
      final entriesBefore = state.allEntries;
      final todayBefore = state.todayEntries;
      final metricsBefore = state.metrics;
      final artifactsBefore = state.artifacts;
      final llmBefore = state.llmSettings;
      final newArtifact = Artifact(
        id: 'artifact_new',
        type: ArtifactType.weekly,
        content: '本周完成架构验证',
        sourceEntryIds: const ['entry_seed'],
        risks: const [],
        gaps: const [],
        createdAt: DateTime(2026, 8, 25, 12),
        updatedAt: DateTime(2026, 8, 25, 12),
      );

      await state.updateArtifact(newArtifact);

      expect(state.artifacts, isNot(same(artifactsBefore)));
      expect(state.artifacts.map((artifact) => artifact.id), [
        'artifact_new',
        'artifact_seed',
      ]);
      expect(state.allEntries, same(entriesBefore));
      expect(state.todayEntries, same(todayBefore));
      expect(state.metrics, same(metricsBefore));
      expect(state.llmSettings, same(llmBefore));
      expect(state.theme, ThemeModePreference.light);
    });

    test('证据更新只替换证据快照并保持产物与设置快照稳定', () async {
      final state = await _createBootstrappedState();
      final entriesBefore = state.allEntries;
      final todayBefore = state.todayEntries;
      final metricsBefore = state.metrics;
      final artifactsBefore = state.artifacts;
      final llmBefore = state.llmSettings;
      final edited = state.allEntries.single.copy()
        ..action = '补充了定向刷新验证';

      await state.updateEntry(edited);

      expect(state.allEntries, isNot(same(entriesBefore)));
      expect(state.todayEntries, isNot(same(todayBefore)));
      expect(state.metrics, isNot(same(metricsBefore)));
      expect(state.allEntries.single.action, '补充了定向刷新验证');
      expect(state.artifacts, same(artifactsBefore));
      expect(state.llmSettings, same(llmBefore));
      expect(state.theme, ThemeModePreference.light);
    });
  });
}

Future<AppState> _createBootstrappedState() async {
  final now = DateTime.now();
  final entry = Entry(
    id: 'entry_seed',
    date: now,
    task: '验证应用状态边界',
    context: '架构优化完成后',
    action: '运行行为测试',
    result: '已有初始结果',
    blocker: '',
    tags: const ['架构'],
    createdAt: now,
    updatedAt: now,
  );
  final question = EvidenceQuestion(
    id: 'question_seed',
    entryId: entry.id,
    kind: QuestionKind.blocker,
    prompt: '遇到了什么难点？',
    reason: '难点为空',
    status: QuestionStatus.pending,
    createdAt: now,
    updatedAt: now,
  );
  final artifact = Artifact(
    id: 'artifact_seed',
    type: ArtifactType.resume,
    content: '初始产物',
    sourceEntryIds: const ['entry_seed'],
    risks: const [],
    gaps: const ['缺少量化结果'],
    createdAt: DateTime(2026, 8, 25, 8),
    updatedAt: DateTime(2026, 8, 25, 8),
  );
  SharedPreferences.setMockInitialValues({
    'entries_v1': jsonEncode([entry.toJson()]),
    'questions_v1': jsonEncode([question.toJson()]),
    'answers_v1': '[]',
    'artifacts_v1': jsonEncode([artifact.toJson()]),
    'settings_theme': ThemeModePreference.light.name,
    'settings_llm': jsonEncode({
      'provider': 'fake-provider',
      'baseUrl': 'https://example.invalid/v1',
      'model': 'fake-model',
      'enabled': true,
    }),
  });
  FlutterSecureStorage.setMockInitialValues({});
  final state = await AppState.create();
  await state.bootstrap();
  return state;
}
