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
}) => EvidenceQuestion(
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
              createdAt: DateTime(2026, 8, 14),
            ),
          ],
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
          'e1': [_question()],
        },
        {},
      );
      expect(md, contains('# 留痕 · 全部证据导出'));
      expect(md, contains('> 共 2 条证据'));
      expect(md, contains('## 证据 1'));
      expect(md, contains('## 证据 2'));
      expect(md, contains('---'));
      expect(md, contains('给新同事做 SQL 培训'));
      expect(md, contains('第二条记录'));
    });
  });

  group('artifactFileName / artifactToMarkdown', () {
    Artifact artifact({ArtifactType type = ArtifactType.resume}) => Artifact(
      id: 'a1',
      type: type,
      content: '## 一、行动与结果\n- 完成 A 项目\n',
      sourceEntryIds: const ['e1'],
      risks: const ['AI 生成内容未经人工核对，请逐条验证。'],
      gaps: const ['AI 生成内容不保证覆盖全部缺失证据，请自行核对。'],
      createdAt: DateTime(2026, 8, 14, 9),
      updatedAt: DateTime(2026, 8, 14, 10),
    );

    test('产物文件名使用类型 label + 时间戳', () {
      expect(
        artifactFileName(artifact(), DateTime(2026, 8, 14, 21, 40)),
        '简历要点-20260814-2140.md',
      );
      expect(
        artifactFileName(
          artifact(type: ArtifactType.weekly),
          DateTime(2026, 8, 14, 21, 40),
        ),
        '周报-20260814-2140.md',
      );
      expect(
        artifactFileName(
          artifact(type: ArtifactType.interview),
          DateTime(2026, 8, 14, 21, 40),
        ),
        '面试反馈-20260814-2140.md',
      );
    });

    test('产物导出含标题、免责声明与原文', () {
      final md = artifactToMarkdown(artifact());
      expect(md, startsWith('# 简历要点 · 2026年8月14日'));
      expect(md, contains('> AI 可能会犯错，请认真检查。'));
      expect(md, contains('## 一、行动与结果'));
      expect(md, contains('- 完成 A 项目'));
    });

    test('结构化产物导出为可读 Markdown 而不是原始 JSON', () {
      final a = Artifact(
        id: 'a3',
        type: ArtifactType.resume,
        content: '{"raw":true}',
        sourceEntryIds: const ['e1'],
        risks: const ['数字需要核对'],
        gaps: const ['缺少节省时间'],
        structuredContent:
            '{"schemaVersion":"artifact.v1","artifactType":"resume",'
            '"title":"简历要点","summary":"有行动记录。",'
            '"sections":[{"id":"resumeBullets","title":"可直接使用",'
            '"items":[{"text":"编写自动化脚本。","evidenceRefs":["e1"],'
            '"missingProof":["节省时间"],"status":"needs_verification"}]}],'
            '"evidenceRefs":["e1"],"missingEvidence":["缺少节省时间"],'
            '"risks":["数字需要核对"]}',
        createdAt: DateTime(2026, 8, 14, 9),
        updatedAt: DateTime(2026, 8, 14, 10),
      );
      final md = artifactToMarkdown(a);
      expect(md, contains('## 可直接使用'));
      expect(md, contains('- 编写自动化脚本。'));
      expect(md, contains('依据：e1'));
      expect(md, isNot(contains('schemaVersion')));
      expect(artifactCopyText(a), contains('编写自动化脚本。'));
      expect(artifactMarkdownSource(a), contains('# 简历要点'));
      expect(artifactMarkdownSource(a), contains('## 可直接使用'));
      expect(artifactMarkdownSource(a), isNot(contains('schemaVersion')));
    });

    test('空内容产物导出不崩溃', () {
      final a = Artifact(
        id: 'a2',
        type: ArtifactType.interview,
        content: '   ',
        sourceEntryIds: const [],
        risks: const [],
        gaps: const [],
        createdAt: DateTime(2026, 8, 14),
        updatedAt: DateTime(2026, 8, 14),
      );
      final md = artifactToMarkdown(a);
      expect(md, contains('# 面试反馈'));
    });
  });
}
