// Markdown 导出测试：单条与全部均为规范 Markdown 纯函数。
import 'package:daily_asking/core/export/markdown_exporter.dart';
import 'package:daily_asking/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry({String id = 'e1', String task = '给新同事做 SQL 培训'}) => Entry(
      id: id,
      date: DateTime(2026, 8, 14),
      task: task,
      context: '新同事刚入职，需要快速上手取数',
      action: '编写了带参数化的培训脚本与讲义',
      result: '3 天内完成 2 场培训，组内 5 人可独立取数',
      blocker: '部分同事对 SQL 基础不熟',
      tags: const ['sql', '培训'],
      createdAt: DateTime(2026, 8, 14, 9),
      updatedAt: DateTime(2026, 8, 14, 10),
    );

EvidenceQuestion _question({
  String id = 'q1',
  QuestionKind kind = QuestionKind.result,
  String prompt = '这次培训的结果如何验证？',
  QuestionStatus status = QuestionStatus.answered,
}) =>
    EvidenceQuestion(
      id: id,
      entryId: 'e1',
      kind: kind,
      prompt: prompt,
      reason: '结果字段有机会量化',
      status: status,
      createdAt: DateTime(2026, 8, 14),
      updatedAt: DateTime(2026, 8, 14),
    );

void main() {
  group('singleFileName / allFileName', () {
    test('含时间戳且扩展名为 .md', () {
      final f = singleFileName(DateTime(2026, 8, 14, 21, 40));
      expect(f, 'daily-asking-20260814-2140.md');
      final a = allFileName(DateTime(2026, 8, 14, 21, 40));
      expect(a, 'daily-asking-all-20260814-2140.md');
    });
  });

  group('entryToMarkdown', () {
    test('完整字段输出规范结构', () {
      final q = _question();
      final md = entryToMarkdown(
        _entry(),
        [q],
        {
          q.id: [
            EvidenceAnswer(
                id: 'a1',
                questionId: q.id,
                content: '通过考核问卷与一周后的独立取数记录验证',
                createdAt: DateTime(2026, 8, 14)),
          ]
        },
      );
      expect(md, contains('## 2026年8月14日'));
      expect(md, contains('**任务**：给新同事做 SQL 培训'));
      expect(md, contains('**完整度**'));
      expect(md, contains('- **背景**：新同事刚入职，需要快速上手取数'));
      expect(md, contains('- **具体行动**：编写了带参数化的培训脚本与讲义'));
      expect(md, contains('- **结果 / 验证**：3 天内完成 2 场培训，组内 5 人可独立取数'));
      expect(md, contains('- **难点 / 取舍**：部分同事对 SQL 基础不熟'));
      expect(md, contains('- **标签**：#sql #培训'));
      expect(md, contains('### 追问与回答'));
      expect(md, contains('【结果/验证】这次培训的结果如何验证？ → **已答**：通过考核问卷与一周后的独立取数记录验证'));
    });

    test('追问未回答时标状态，不留空', () {
      final q = _question(status: QuestionStatus.pending);
      final md = entryToMarkdown(_entry(), [q], {});
      expect(md, contains('【结果/验证】这次培训的结果如何验证？（待补充）'));
    });

    test('空字段不输出占位行，避免误导', () {
      final e = Entry(
        id: 'e2',
        date: DateTime(2026, 8, 13),
        task: '只有一句话',
        createdAt: DateTime(2026, 8, 13),
        updatedAt: DateTime(2026, 8, 13),
      );
      final md = entryToMarkdown(e, [], {});
      expect(md, contains('**任务**：只有一句话'));
      expect(md, isNot(contains('- **背景**')));
      expect(md, isNot(contains('追问与回答')));
    });
  });

  group('allEntriesToMarkdown', () {
    test('含标题、导出说明与条目分隔', () {
      final md = allEntriesToMarkdown(
        [_entry(id: 'e1'), _entry(id: 'e2', task: '第二条记录')],
        {
          'e1': [_question()]
        },
        {},
      );
      expect(md, contains('# 晨昏证据图谱 · 全部证据导出'));
      expect(md, contains('> 共 2 条证据'));
      expect(md, contains('## 证据 1'));
      expect(md, contains('## 证据 2'));
      expect(md, contains('---'));
      expect(md, contains('给新同事做 SQL 培训'));
      expect(md, contains('第二条记录'));
    });
  });
}