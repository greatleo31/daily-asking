import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:daily_asking/core/export/markdown_exporter.dart';
import 'package:daily_asking/core/models.dart';
import 'package:daily_asking/core/transfer/import_parser.dart';
import 'package:daily_asking/core/transfer/transfer_schema.dart';

final _date = DateTime(2024, 2, 29);
Entry _entry(
  String id, {
  String task = '完成任务',
  String context = '背景\n第二行',
  List<String> tags = const ['开发', '验证'],
}) => Entry(
  id: id,
  date: _date,
  task: task,
  context: context,
  action: '具体行动',
  result: '可验证结果',
  blocker: '难点',
  tags: tags,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026, 2),
);
EvidenceQuestion _question(String id, QuestionStatus status) =>
    EvidenceQuestion(
      id: id,
      entryId: 'original',
      kind: QuestionKind.result,
      prompt: '如何验证？',
      reason: '无法在 Markdown 中保留',
      status: status,
      createdAt: _date,
      updatedAt: _date,
    );
ParsedImport _parse(String text) =>
    parseImportMarkdown(text, source: 'fixture.md');

void main() {
  test(
    'actual single-entry exporter roundtrip retains narrative and marks loss',
    () {
      final original = _entry('original');
      final parsed = _parse(entryToMarkdown(original, [], {}));
      expect(parsed.issues, isEmpty);
      final candidate = parsed.candidates.single;
      final entry = candidate.entry;
      expect(entry.id, startsWith('e_'));
      expect(entry.id, isNot(original.id));
      expect(entry.task, original.task);
      expect(entry.context, original.context);
      expect(entry.action, original.action);
      expect(entry.result, original.result);
      expect(entry.blocker, original.blocker);
      expect(entry.tags, original.tags);
      expect(entry.date, _date);
      expect(entry.createdAt, _date);
      expect(entry.updatedAt, _date);
      expect(candidate.incomplete, isTrue);
      expect(candidate.hasOriginalId, isFalse);
      expect(candidate.legacy, isFalse);
    },
  );

  test(
    'actual all exporter section headings and separators do not create entries',
    () {
      final parsed = _parse(
        allEntriesToMarkdown(
          [_entry('one'), _entry('two', task: '第二条', tags: [])],
          {},
          {},
        ),
      );
      expect(parsed.issues, isEmpty);
      expect(parsed.candidates.length, 2);
      expect(parsed.candidates.last.entry.task, '第二条');
      expect(parsed.candidates.last.entry.blocker, '难点');
      expect(parsed.ignoredLines, greaterThan(0));
    },
  );

  test(
    'actual parentheses preserve all unanswered statuses; arrow joins answers',
    () {
      final questions = [
        for (final status in QuestionStatus.values)
          _question(status.name, status),
      ];
      questions.add(_question('has-answer', QuestionStatus.skip));
      final parsed = _parse(
        entryToMarkdown(_entry('original'), questions, {
          'has-answer': [
            EvidenceAnswer(
              id: 'a1',
              questionId: 'has-answer',
              content: '第一条',
              createdAt: _date,
            ),
            EvidenceAnswer(
              id: 'a2',
              questionId: 'has-answer',
              content: '第二条\n补充',
              createdAt: _date,
            ),
          ],
        }),
      );
      expect(parsed.issues, isEmpty);
      final candidate = parsed.candidates.single;
      expect(
        candidate.questions.take(4).map((q) => q.status),
        QuestionStatus.values,
      );
      expect(candidate.questions.last.status, QuestionStatus.answered);
      expect(
        candidate.questions.every(
          (q) => q.reason.isEmpty && q.entryId == candidate.entry.id,
        ),
        isTrue,
      );
      expect(candidate.answers.single.content, '第一条；第二条\n补充');
      expect(candidate.answers.single.questionId, candidate.questions.last.id);
      expect(candidate.incomplete, isTrue);
    },
  );

  test('multiline prompt is kept', () {
    final question = EvidenceQuestion(
      id: 'q',
      entryId: 'original',
      kind: QuestionKind.context,
      prompt: '第一行\n第二行',
      reason: '',
      status: QuestionStatus.pending,
      createdAt: _date,
      updatedAt: _date,
    );
    final parsed = _parse(entryToMarkdown(_entry('original'), [question], {}));
    expect(parsed.issues, isEmpty);
    expect(parsed.candidates.single.questions.single.prompt, question.prompt);
  });

  test(
    'forged and repeated backward labels remain body, completeness recomputed',
    () {
      final original = Entry(
        id: 'original',
        date: _date,
        task: '真实任务\n**任务**：不是另一字段\n\n**完整度**：100%\n\n仍然是正文',
        context: '实际背景\n**任务**：背景中的伪造\n**完整度**：100%\n- **背景**：重复标签',
        createdAt: _date,
        updatedAt: _date,
      );
      final parsed = _parse(entryToMarkdown(original, [], {}));
      expect(parsed.issues, isEmpty);
      expect(parsed.candidates.single.entry.task, original.task);
      expect(parsed.candidates.single.entry.context, original.context);
      expect(parsed.candidates.single.entry.completenessPercent(), 40);
    },
  );

  test('known numeric completeness is ignored even when inconsistent', () {
    final parsed = _parse('## 2024年2月29日\n\n**任务**：仅任务\n\n**完整度**：100%\n');
    expect(parsed.candidates.single.entry.completenessPercent(), 20);
    expect(parsed.candidates.single.entry.task, '仅任务');
  });

  test('unknown lines outside body are ignored and counted; body retained', () {
    final parsed = _parse('前导\n## 2024年2月29日\n未知前导\n**任务**：任务\n正文续行\n');
    expect(parsed.ignoredLines, 2);
    expect(parsed.candidates.single.entry.task, '任务\n正文续行');
  });

  test('invalid date and empty record do not suppress a valid neighbor', () {
    final parsed = _parse('''## 2024年2月30日
**任务**：不可能的日期
## 2024年3月1日
**完整度**：100%
## 2024年3月2日
**任务**：有效
''');
    expect(parsed.candidates.single.entry.task, '有效');
    expect(parsed.candidates.single.index, 3);
    expect(parsed.issues.map((i) => i.index), [1, 2]);
    expect(parsed.issues.first.reason, contains('日期无效'));
    expect(parsed.issues.last.reason, contains('正文'));
  });

  test('bad child kind/status invalidates only its owning Markdown record', () {
    for (final question in ['- 【不存在】问题（待补充）', '- 【背景】问题（未知状态）', '- 【背景】无状态']) {
      final parsed = _parse(
        '## 2024年3月1日\n**任务**：坏\n### 追问与回答\n$question\n## 2024年3月2日\n**任务**：好',
      );
      expect(parsed.candidates.single.entry.task, '好');
      expect(parsed.issues.single.index, 1);
      expect(parsed.issues.single.reason, contains('追问'));
    }
  });

  test(
    'empty/non-record files rejected; indented headings never start records',
    () {
      for (final text in ['', '# 其它文档\n正文', ' ## 2024年2月29日\n**任务**：不是标题']) {
        final parsed = _parse(text);
        expect(parsed.candidates, isEmpty);
        expect(parsed.issues.single.index, 0);
      }
    },
  );

  test('more than 5000 blocks rejects all, including invalid blocks', () {
    final parsed = _parse(
      List.filled(5001, '## 2024年99月1日\n**任务**：测试').join('\n'),
    );
    expect(parsed.candidates, isEmpty);
    expect(parsed.issues.single.reason, '文件包含超过 5000 条记录');
  });

  test(
    'dispatch validates extension and recognizes JSON content before Markdown',
    () {
      final json = jsonEncode({
        'schema': transferSchemaV1,
        'entries': [
          {'date': '2024-02-29', 'task': '旧版'},
        ],
      });
      for (final extension in ['.json', '.JSON', '.md']) {
        final parsed = parseImportText(
          '\uFEFF$json',
          source: 'old$extension',
          extension: extension,
        );
        expect(parsed.issues, isEmpty);
        expect(parsed.candidates.single.legacy, isTrue);
      }
      expect(
        parseImportText(
          json,
          source: 'bad.zip',
          extension: '.zip',
        ).issues.single.reason,
        '无法识别的文件格式',
      );
      expect(
        parseImportText(
          '## 2024年2月29日\n**任务**：文本',
          source: 'bad.json',
          extension: '.json',
        ).candidates,
        isEmpty,
      );
      expect(
        parseImportText(
          '\uFEFF## 2024-02-29\r\n**任务**：文本',
          source: 'ok.MD',
          extension: '.MD',
        ).candidates.single.entry.task,
        '文本',
      );
    },
  );

  test(
    'tags with spaces remain explicitly lossy, leading literal hash survives',
    () {
      final parsed = _parse(
        entryToMarkdown(
          _entry('original', tags: ['含 空格', '#导入-20260101']),
          [],
          {},
        ),
      );
      expect(parsed.candidates.single.incomplete, isTrue);
      expect(parsed.candidates.single.entry.tags, ['含', '#导入-20260101']);
    },
  );
}
