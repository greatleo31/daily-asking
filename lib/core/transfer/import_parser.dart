import 'dart:convert';

import '../models.dart';
import '../utils.dart';
import 'transfer_schema.dart';

ParsedImport parseImportText(
  String text, {
  required String source,
  required String extension,
}) {
  final ext = extension.toLowerCase();
  if (ext != '.json' && ext != '.md') {
    return _rejected(source, '无法识别的文件格式');
  }
  final clean = text.replaceFirst(RegExp(r'^\uFEFF'), '');
  final start = clean.trimLeft();
  if (ext == '.json' || start.startsWith('{') || start.startsWith('[')) {
    return parseTransferJson(clean, source: source);
  }
  return parseImportMarkdown(clean, source: source);
}

ParsedImport _rejected(String source, String reason) => ParsedImport(
  issues: [ImportIssue(source: source, index: 0, reason: reason)],
);

final _heading = RegExp(r'^## (\d{4}年.*|\d{4}-.*)$');
final _section = RegExp(r'^## 证据 \d+ · .+$');
final _field = RegExp(r'^- \*\*(背景|具体行动|结果 / 验证|难点 / 取舍|标签)\*\*：(.*)$');
final _completeness = RegExp(r'^\*\*完整度\*\*：\d+%$');
const _fieldNames = ['背景', '具体行动', '结果 / 验证', '难点 / 取舍', '标签'];

/// Best-effort reader of the existing, unescaped, human-readable exporter.
/// Ordered, one-use slots keep repeated/backward labels in their body field.
/// Text impersonating a still-unused forward slot is intrinsically ambiguous;
/// all Markdown candidates therefore carry the incomplete marker.
ParsedImport parseImportMarkdown(String text, {required String source}) {
  final lines = const LineSplitter().convert(
    text.replaceFirst(RegExp(r'^\uFEFF'), ''),
  );
  final blocks = <_MarkdownBlock>[];
  var ignored = 0;
  _MarkdownBlock? current;
  for (final line in lines) {
    if (_section.hasMatch(line)) {
      ignored++;
      continue;
    }
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      if (blocks.length == maxImportEntries) {
        return _rejected(source, '文件包含超过 5000 条记录');
      }
      current = _MarkdownBlock(heading.group(1)!);
      blocks.add(current);
    } else if (current == null) {
      ignored++;
    } else {
      current.lines.add(line);
    }
  }
  if (blocks.isEmpty) {
    return ParsedImport(
      issues: [ImportIssue(source: source, index: 0, reason: '未找到可导入的记录日期标题')],
      ignoredLines: ignored,
    );
  }
  final candidates = <ImportCandidate>[];
  final issues = <ImportIssue>[];
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    final date = _headingDate(block.heading);
    if (date == null) {
      issues.add(
        ImportIssue(
          source: source,
          index: i + 1,
          reason: '记录标题日期无效：${block.heading}',
        ),
      );
      continue;
    }
    final parsed = _parseBlock(block, date, source, i + 1);
    ignored += parsed.ignoredLines;
    candidates.addAll(parsed.candidates);
    issues.addAll(parsed.issues);
  }
  return ParsedImport(
    candidates: candidates,
    issues: issues,
    ignoredLines: ignored,
  );
}

class _MarkdownBlock {
  _MarkdownBlock(this.heading);
  final String heading;
  final lines = <String>[];
}

DateTime? _headingDate(String heading) {
  final match =
      RegExp(r'^(\d{4})年(\d{1,2})月(\d{1,2})日$').firstMatch(heading) ??
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(heading);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

ParsedImport _parseBlock(
  _MarkdownBlock block,
  DateTime date,
  String source,
  int index,
) {
  final lines = List<String>.of(block.lines);
  var ignored = 0;
  // allEntriesToMarkdown adds a trailing separator, not part of the last field.
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
    ignored++;
  }
  if (lines.isNotEmpty && lines.last == '---') {
    lines.removeLast();
    ignored++;
  }

  // The exporter puts the real completeness line AFTER the complete task text.
  // Select its last occurrence before the next structural slot, so a repeated
  // completeness label within the task does not truncate the task.
  var completenessIndex = -1;
  final taskIndex = lines.indexWhere((line) => line.startsWith('**任务**：'));
  if (taskIndex >= 0) {
    for (var i = taskIndex + 1; i < lines.length; i++) {
      if (_field.hasMatch(lines[i]) || lines[i] == '### 追问与回答') break;
      if (_completeness.hasMatch(lines[i]) &&
          lines[i - 1].trim().isEmpty &&
          (i + 1 == lines.length || lines[i + 1].trim().isEmpty)) {
        completenessIndex = i;
      }
    }
  }

  // Slots: task, completeness, context, action, result, blocker, tags, questions.
  final fields = List.generate(7, (_) => <String>[]);
  var slot = -1;
  var bodySlot = -1;
  var inQuestions = false;
  final questionTexts = <List<String>>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!inQuestions && line == '### 追问与回答') {
      inQuestions = true;
      slot = 7;
      bodySlot = -1;
      continue;
    }
    if (inQuestions) {
      if (line.startsWith('- 【')) {
        questionTexts.add([line]);
      } else if (questionTexts.isNotEmpty && line.trim().isNotEmpty) {
        questionTexts.last.add(line);
      } else {
        ignored++;
      }
      continue;
    }
    if (i == taskIndex && slot < 0) {
      slot = 0;
      bodySlot = 0;
      fields[0].add(line.substring('**任务**：'.length));
      continue;
    }
    if (i == completenessIndex && slot <= 0) {
      slot = 1;
      bodySlot = -1;
      continue;
    }
    final field = _field.firstMatch(line);
    if (field != null) {
      final next = _fieldNames.indexOf(field.group(1)!) + 2;
      if (next > slot) {
        slot = next;
        bodySlot = next;
        fields[next].add(field.group(2)!);
        continue;
      }
    }
    if (bodySlot >= 0) {
      fields[bodySlot].add(line);
    } else {
      ignored++;
    }
  }
  String value(int slot) => fields[slot].join('\n').trim();
  if ([0, 2, 3, 4, 5].every((slot) => value(slot).isEmpty)) {
    return ParsedImport(
      issues: [ImportIssue(source: source, index: index, reason: '记录没有可识别的正文')],
      ignoredLines: ignored,
    );
  }
  final entry = Entry(
    id: genId(prefix: 'e_'),
    date: date,
    task: value(0),
    context: value(2),
    action: value(3),
    result: value(4),
    blocker: value(5),
    tags: value(6)
        .split(RegExp(r'\s+'))
        .where((s) => s.startsWith('#') && s.length > 1)
        .map((s) => s.substring(1))
        .toList(),
    createdAt: date,
    updatedAt: date,
  );
  final questions = <EvidenceQuestion>[];
  final answers = <EvidenceAnswer>[];
  final reasons = <String>[];
  for (var i = 0; i < questionTexts.length; i++) {
    final text = questionTexts[i].join('\n').trim();
    final answered = RegExp(
      r'^- 【([^】]+)】(.*?) → \*\*([^*]+)\*\*：(.*)$',
      dotAll: true,
    ).firstMatch(text);
    final unanswered = RegExp(
      r'^- 【([^】]+)】(.*?)（([^（）]+)）$',
      dotAll: true,
    ).firstMatch(text);
    final match = answered ?? unanswered;
    if (match == null) {
      reasons.add('追问 ${i + 1} 格式无效');
      continue;
    }
    final kinds = QuestionKind.values.where(
      (kind) => kind.label == match.group(1),
    );
    const statuses = {
      '待补充': QuestionStatus.pending,
      '已答': QuestionStatus.answered,
      '稍后': QuestionStatus.later,
      '已跳过': QuestionStatus.skip,
    };
    final status = statuses[match.group(3)];
    if (kinds.isEmpty || status == null) {
      reasons.add('追问 ${i + 1} 的类型或状态未知');
      continue;
    }
    final question = EvidenceQuestion(
      id: genId(prefix: 'q_'),
      entryId: entry.id,
      kind: kinds.single,
      prompt: match.group(2)!,
      reason: '',
      status: status,
      createdAt: date,
      updatedAt: date,
    );
    questions.add(question);
    if (answered != null) {
      answers.add(
        EvidenceAnswer(
          id: genId(prefix: 'a_'),
          questionId: question.id,
          content: answered.group(4)!,
          createdAt: date,
        ),
      );
    }
  }
  if (reasons.isNotEmpty) {
    return ParsedImport(
      issues: [
        ImportIssue(source: source, index: index, reason: reasons.join('；')),
      ],
      ignoredLines: ignored,
    );
  }
  return ParsedImport(
    candidates: [
      ImportCandidate(
        entry: entry,
        questions: questions,
        answers: answers,
        hasOriginalId: false,
        incomplete: true,
        legacy: false,
        source: source,
        index: index,
      ),
    ],
    ignoredLines: ignored,
  );
}
