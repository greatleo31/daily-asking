// 产物提示词工厂测试：三种产物统一输出 Markdown-first。
import 'package:daily_asking/core/llm/llm_client.dart';
import 'package:daily_asking/core/llm/prompts.dart';
import 'package:daily_asking/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('systemPromptFor Markdown-first 契约', () {
    for (final type in ArtifactType.values) {
      test('${type.label} 要求 Markdown 结构与证据边界', () {
        final p = systemPromptFor(type);
        for (final section in ['# 角色', '# 目标', '# 输出结构', '## 边界']) {
          expect(p, contains(section), reason: '缺少「$section」');
        }
        expect(p, contains('Markdown'));
        expect(p, contains('只输出 Markdown 正文'));
        expect(p, contains('严禁编造'));
        expect(p, contains('不要输出 JSON'));
      });
    }
  });

  test('简历要点保留复制友好的章节规则', () {
    final p = systemPromptFor(ArtifactType.resume);
    expect(p, contains('简历要点'));
    expect(p, contains('逐条依据'));
    expect(p, contains('缺失与建议'));
    expect(p, contains('动词开头'));
  });

  test('周报使用七段公司结构章节', () {
    final p = systemPromptFor(ArtifactType.weekly);
    for (final section in [
      '# 周报',
      '## 本周完成工作',
      '## 本周工作总结',
      '## 下周工作计划',
      '## 需协调与帮助',
      '## 备注',
      '## 图片',
      '## 附件',
    ]) {
      expect(p, contains(section), reason: '缺少「$section」');
    }
    expect(p, contains('普通文本“无”'));
    expect(p, isNot(contains('## 进行中')));
    expect(p, isNot(contains('## 风险与阻塞')));
    expect(p, isNot(contains('## 数据与可验证成果')));
    expect(artifactPromptVersion, 'markdown.v2');
  });

  test('面试反馈保留逐条点评和补强章节且不生成评分', () {
    final p = systemPromptFor(ArtifactType.interview);
    expect(p, contains('资深技术面试官'));
    for (final keyword in [
      '总体评价',
      '逐条点评',
      '有效性',
      '亮点',
      '偏浅处',
      '扩展建议',
      '学习方向',
      '最该优先补强的三件事',
    ]) {
      expect(p, contains(keyword), reason: '缺少「$keyword」');
    }
    expect(p, contains('不生成评分'));
  });

  test('用户消息包含真实记录 id 与参考日期', () {
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
    final message = payload.buildUserMessage(
      referenceDate: DateTime(2026, 8, 26),
    );
    expect(message, contains('记录 id=e1'));
    expect(message, contains('当前参考日期：2026-08-26'));
    expect(message, isNot(contains('证据名')));
    expect(message, isNot(contains('证据 id=')));
  });

  test('出站披露只包含简明确认句', () {
    final payload = OutboundPayload(
      entries: const [],
      artifactType: ArtifactType.weekly,
    );
    final disclosure = payload.toDisclosure();
    expect(disclosure, '将访问已配置的 AI 服务生成内容，是否确认？');
  });
}