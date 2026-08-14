// 产物提示词工厂测试：三种产物都必须具备五段式结构（角色/目标/背景/输出结构/边界）。
import 'package:daily_asking/core/llm/llm_client.dart';
import 'package:daily_asking/core/llm/prompts.dart';
import 'package:daily_asking/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('systemPromptFor 五段式结构', () {
    const fiveSections = ['# 角色', '# 目标', '# 背景', '# 输出结构', '## 边界'];

    for (final type in ArtifactType.values) {
      test('${type.label} 包含五个部分', () {
        final p = systemPromptFor(type);
        for (final section in fiveSections) {
          expect(p, contains(section), reason: '缺少「$section」');
        }
      });

      test('${type.label} 强制边界：只用证据、禁止编造', () {
        final p = systemPromptFor(type);
        expect(p, contains('严禁编造'));
        expect(p, contains('待补充'));
        expect(p, contains('不要输出解释性开场白'));
      });
    }
  });

  test('简历要点符合项目经历撰写结构：动词开头 + 量化优先 + 逐条依据', () {
    final p = systemPromptFor(ArtifactType.resume);
    expect(p, contains('可直接粘贴进简历'));
    expect(p, contains('动词开头'));
    expect(p, contains('量化'));
    expect(p, contains('## 逐条依据'));
    expect(p, contains('## 缺失与建议'));
  });

  test('周报采用业界标准五节且固定可自动化', () {
    final p = systemPromptFor(ArtifactType.weekly);
    for (final section in ['本周完成', '进行中', '风险与阻塞', '下周计划']) {
      expect(p, contains(section));
    }
    expect(p, contains('可直接粘贴'));
    expect(p, contains('（无）'));
  });

  test('面试反馈为面试官+从业1-3年视角，含有效性/扩展性/亮点/偏浅点/热点', () {
    final p = systemPromptFor(ArtifactType.interview);
    expect(p, contains('资深技术面试官'));
    expect(p, contains('从业 1-3 年'));
    for (final keyword in ['总体评价', '逐条点评', '有效性', '亮点', '偏浅处', '扩展建议', '热点与学习方向', '最该优先补强的三件事']) {
      expect(p, contains(keyword), reason: '缺少「$keyword」');
    }
  });

  test('OutboundPayload.buildSystemPrompt 委托给 prompts 工厂', () {
    final payload = OutboundPayload(
      entries: [
        Entry(
          id: 'e1',
          date: DateTime(2026, 8, 14),
          task: '给新同事做 SQL 培训',
          createdAt: DateTime(2026, 8, 14),
          updatedAt: DateTime(2026, 8, 14),
        ),
      ],
      artifactType: ArtifactType.interview,
    );
    expect(payload.buildSystemPrompt(ArtifactType.interview),
        systemPromptFor(ArtifactType.interview));
  });
}