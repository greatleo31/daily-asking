// 产物内容解析测试：Markdown → 结构化视图（纯 Dart，无 UI 依赖）。
import 'package:daily_asking/artifacts/artifact_content_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseArtifactContent', () {
    test('# 标题 + ## 章节可解析', () {
      const md = '# 简历要点\n\n## 一、行动与结果\n- 完成 A 项目\n- 复盘中沉淀出 3 条规范\n';
      final p = parseArtifactContent(md);
      expect(p.title, '简历要点');
      expect(p.sections, hasLength(1));
      expect(p.sections.first.heading, '一、行动与结果');
      expect(p.sections.first.lines, hasLength(2));
      expect(p.hasStructure, isTrue);
    });

    test('未识别行进 preamble 不丢内容', () {
      const md = '这是开头的一段说明\n\n## 章节\n内容\n';
      final p = parseArtifactContent(md);
      expect(p.preamble, ['这是开头的一段说明']);
      expect(p.sections, hasLength(1));
    });

    test('### 小节归入对应章节', () {
      const md = '## 逐条点评\n### 第一条\n- 有效性：直接可复用\n### 第二条\n- 亮点：有量化\n';
      final p = parseArtifactContent(md);
      expect(p.sections, hasLength(1));
      expect(p.sections.first.subsections, hasLength(2));
      expect(p.sections.first.subsections.first.title, '第一条');
    });

    test('纯文本无结构回退：hasStructure=false 且不崩溃', () {
      final p = parseArtifactContent('只有一行普通文本，没有任何标题。');
      expect(p.hasStructure, isFalse);
      expect(p.preamble, ['只有一行普通文本，没有任何标题。']);
      expect(p.sections, isEmpty);
    });
  });

  group('buildInterviewFeedbackView', () {
    const md = '''
# 面试反馈（AI 生成）

## 一、总体评价
基础扎实，但缺乏大型项目实战证据。

## 二、逐条点评

### 1. 晨昏记录工具开发
- 有效性：体现自驱与工具链意识
- 亮点：把日常记录沉淀成可复用流程
- 偏浅处：未提及性能优化
- 扩展建议：补充压测数据与上线后的量化指标

### 2. 团队培训
- 有效性：能证明沟通与文档能力
- 亮点：培训材料可复用

## 三、热点与学习方向
- Agent / LLM 应用落地
- 本地模型部署与成本控制

## 四、最该优先补强的三件事
1. 大型项目的架构设计
2. 数据埋点与指标衡量
3. 公开分享与技术文章输出
''';

    test('interview 结构化解析（总体/逐条/热点/补强）', () {
      final v = buildInterviewFeedbackView(md);
      expect(v.isStructured, isTrue);
      expect(v.overall, contains('基础扎实'));
      expect(v.items, hasLength(2));
      expect(v.hotspots, hasLength(2));
      expect(v.topThree, hasLength(3));
      expect(v.pendingCount, 0);
      expect(v.shallowCount, 1); // 只有第一条有「偏浅处：」
      expect(v.otherSections, isEmpty);
    });

    test('逐条点评条目四字段解析', () {
      final v = buildInterviewFeedbackView(md);
      final first = v.items.first;
      expect(first.title, '1. 晨昏记录工具开发');
      expect(first.effective, contains('自驱'));
      expect(first.highlight, contains('可复用流程'));
      expect(first.shallow, contains('性能优化'));
      expect(first.expand, contains('压测'));
      expect(first.rawLines, isEmpty);
    });

    test('待补充占位计数', () {
      const md2 = '## 一、总体评价\nok\n## 二、逐条点评\n### a\n（待补充：无明确证据）\n### b\n- 有效性：（待补充）\n';
      final v = buildInterviewFeedbackView(md2);
      expect(v.pendingCount, 2);
    });

    test('标题变化时回退不崩溃，未识别章节进 otherSections', () {
      const md3 = '# 自定标题\n\n## 神秘章节\n- 数据1\n\n## 二、逐条点评\n### x\n- 亮点：有量化\n';
      final v = buildInterviewFeedbackView(md3);
      expect(v.isStructured, isTrue);
      expect(v.items, hasLength(1));
      expect(v.otherSections.single.heading, '神秘章节');
      expect(v.overall, isNull);
    });

    test('字段值为空标签时吸收续行为同一字段', () {
      const md4 = '''
## 二、逐条点评
### 1. 某任务
- 有效性：可以作为引子
- 亮点：
- 选择「从零复刻」体现主动学习
- 偏浅处：
- 只做了使用，未涉及原理
- 扩展建议：深挖状态机
''';
      final v = buildInterviewFeedbackView(md4);
      final item = v.items.single;
      expect(item.effective, '可以作为引子');
      expect(item.highlight, '选择「从零复刻」体现主动学习');
      expect(item.shallow, '只做了使用，未涉及原理');
      expect(item.expand, '深挖状态机');
      expect(item.rawLines, isEmpty);
    });

    test('空标签无续行：字段为 null（页面不渲染空标签）', () {
      const md5 =
          '## 二、逐条点评\n### 1. 某任务\n- 亮点：\n- 扩展建议：深挖状态机\n';
      final v = buildInterviewFeedbackView(md5);
      final item = v.items.single;
      expect(item.highlight, isNull);
      expect(item.expand, '深挖状态机');
    });

    test('已知字段出现前的行保留 rawLines', () {
      const md6 =
          '## 二、逐条点评\n### 1. 某任务\n- 前置说明行\n- 有效性：引子\n';
      final v = buildInterviewFeedbackView(md6);
      final item = v.items.single;
      expect(item.effective, '引子');
      expect(item.rawLines, ['前置说明行']);
    });

    test('字段内子标签续行（如「往深挖：」）并入当前字段', () {
      const md7 = '''
## 二、逐条点评
### 1. 某任务
- 扩展建议：准备一次完整运行的 demo：调用模型拿到结果。
- 往深挖：拆解 agent loop 的状态机。
''';
      final v = buildInterviewFeedbackView(md7);
      final item = v.items.single;
      expect(
        item.expand,
        '准备一次完整运行的 demo：调用模型拿到结果。\n往深挖：拆解 agent loop 的状态机。',
      );
      expect(item.rawLines, isEmpty);
    });

    test('纯文本无结构返回 isStructured=false', () {
      final v = buildInterviewFeedbackView('只有一行字。');
      expect(v.isStructured, isFalse);
      expect(v.items, isEmpty);
    });
  });
}