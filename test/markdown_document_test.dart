import 'package:daily_asking/artifacts/markdown_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseMarkdownDocument', () {
    test('将标题、段落和列表分成可复制的顶层块', () {
      const source =
          '# 周报\n\n本周完成了 **迁移**。\n\n- 任务一\n- 任务二\n  - 子任务\n\n## 风险\n无';
      final document = parseMarkdownDocument(source);

      expect(document.blocks.map((block) => block.type), [
        MarkdownBlockType.heading,
        MarkdownBlockType.paragraph,
        MarkdownBlockType.unorderedList,
        MarkdownBlockType.heading,
        MarkdownBlockType.paragraph,
      ]);
      expect(document.blocks[0].raw, '# 周报');
      expect(document.blocks[2].raw, '- 任务一\n- 任务二\n  - 子任务');
      expect(document.blocks.last.raw, '无');
    });

    test('保留代码块、引用和有序列表的原始语法', () {
      const source =
          '> 先确认接口\n> 再写测试\n\n```dart\nfinal answer = 42;\n```\n\n1. 第一步\n2. 第二步';
      final blocks = parseMarkdownDocument(source).blocks;

      expect(blocks[0].type, MarkdownBlockType.quote);
      expect(blocks[0].raw, '> 先确认接口\n> 再写测试');
      expect(blocks[1].type, MarkdownBlockType.code);
      expect(blocks[1].raw, '```dart\nfinal answer = 42;\n```');
      expect(blocks[2].type, MarkdownBlockType.orderedList);
      expect(blocks[2].raw, '1. 第一步\n2. 第二步');
    });

    test('复制块使用原始 Markdown，纯文本转换不靠正则删整篇内容', () {
      const source =
          '# 标题\n\n说明 **重点**，见 [文档](https://example.com)。\n\n- 第一项\n- 第二项';
      final document = parseMarkdownDocument(source);

      expect(
        document.blocks[1].copyText,
        '说明 **重点**，见 [文档](https://example.com)。',
      );
      expect(document.toReadableText(), '标题\n\n说明 重点，见 文档。\n\n• 第一项\n• 第二项');
    });

    test('没有列表语法的无和普通段落不凭空添加圆点', () {
      final document = parseMarkdownDocument('## 风险\n\n无\n\n当前没有更多说明。');

      expect(document.blocks.map((block) => block.type), [
        MarkdownBlockType.heading,
        MarkdownBlockType.paragraph,
        MarkdownBlockType.paragraph,
      ]);
      expect(document.toReadableText(), '  风险\n\n无\n\n当前没有更多说明。');
    });

    test('空白内容不制造虚假的无', () {
      final document = parseMarkdownDocument(' \n\n');
      expect(document.blocks, isEmpty);
      expect(document.toReadableText(), isEmpty);
    });
  });
}
