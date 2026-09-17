import 'dart:convert';

import '../models.dart';
import '../utils.dart';

const transferSchemaV2 = 'daily_asking.export.v2';
const transferSchemaV1 = 'daily_asking.entries.export.v1';
const maxImportEntries = 5000;

class TransferData {
  const TransferData({
    required this.entries,
    required this.questions,
    required this.answers,
  });

  final List<Entry> entries;
  final List<EvidenceQuestion> questions;
  final List<EvidenceAnswer> answers;
}

String encodeTransfer(
  TransferData data, {
  required DateTime exportedAt,
  required String appVersion,
}) => const JsonEncoder.withIndent('  ').convert({
  'schema': transferSchemaV2,
  'schemaVersion': 2,
  'exportedAt': exportedAt.toIso8601String(),
  'appVersion': appVersion,
  'entries': data.entries.map((e) => e.toJson()).toList(),
  'questions': data.questions.map((q) => q.toJson()).toList(),
  'answers': data.answers.map((a) => a.toJson()).toList(),
});

class ImportIssue {
  const ImportIssue({
    required this.source,
    required this.index,
    required this.reason,
  });

  final String source;
  // One-based entry/child row; zero denotes a whole-file rejection.
  final int index;
  final String reason;
}

class ImportCandidate {
  const ImportCandidate({
    required this.entry,
    required this.questions,
    required this.answers,
    required this.hasOriginalId,
    required this.incomplete,
    required this.legacy,
    required this.source,
    required this.index,
  });

  final Entry entry;
  final List<EvidenceQuestion> questions;
  final List<EvidenceAnswer> answers;
  final bool hasOriginalId;
  final bool incomplete;
  final bool legacy;
  final String source;
  final int index;
}

class ParsedImport {
  const ParsedImport({
    this.candidates = const [],
    this.issues = const [],
    this.ignoredLines = 0,
  });

  final List<ImportCandidate> candidates;
  final List<ImportIssue> issues;
  final int ignoredLines;

  factory ParsedImport.combine(Iterable<ParsedImport> imports) {
    final candidates = <ImportCandidate>[];
    final issues = <ImportIssue>[];
    var ignoredLines = 0;
    for (final parsed in imports) {
      candidates.addAll(parsed.candidates);
      issues.addAll(parsed.issues);
      ignoredLines += parsed.ignoredLines;
    }
    return ParsedImport(
      candidates: candidates,
      issues: issues,
      ignoredLines: ignoredLines,
    );
  }
}

/// Parse without consulting local storage: references cannot escape this file.
/// Format failures are report data, never an exception escaping to the caller.
ParsedImport parseTransferJson(String text, {required String source}) {
  try {
    final decoded = jsonDecode(text.replaceFirst(RegExp(r'^\uFEFF'), ''));
    final root = _object(decoded, '文件');
    final schema = root['schema'];
    final version = root['schemaVersion'];
    if ((schema != transferSchemaV1 && schema != transferSchemaV2) ||
        (version is num && version > 2)) {
      throw const FormatException('文件来自更新版本的留痕，请先升级 App');
    }
    final legacy = schema == transferSchemaV1;
    if (!legacy && (version is! int || version != 2)) {
      throw const FormatException('schemaVersion 必须为整数 2');
    }
    final rows = _array(root['entries'], 'entries');
    if (rows.length > maxImportEntries) {
      throw const FormatException('文件包含超过 5000 条记录');
    }
    final questionRows = legacy
        ? const <dynamic>[]
        : _array(root['questions'], 'questions');
    final answerRows = legacy
        ? const <dynamic>[]
        : _array(root['answers'], 'answers');
    return _parseRows(rows, questionRows, answerRows, source, legacy);
  } on FormatException catch (error) {
    return ParsedImport(
      issues: [ImportIssue(source: source, index: 0, reason: error.message)],
    );
  }
}

class _EntryGroup {
  _EntryGroup(this.index, this.originalId);
  final int index;
  final String? originalId;
  Entry? entry;
  final reasons = <String>[];
  final questions = <EvidenceQuestion>[];
  final answers = <EvidenceAnswer>[];
  bool incomplete = false;
}

class _QuestionRow {
  _QuestionRow(this.owner);
  final _EntryGroup? owner;
}

ParsedImport _parseRows(
  List<dynamic> entries,
  List<dynamic> questions,
  List<dynamic> answers,
  String source,
  bool legacy,
) {
  final groups = <_EntryGroup>[];
  final owners = <String, List<_EntryGroup>>{};
  final issues = <ImportIssue>[];
  for (var i = 0; i < entries.length; i++) {
    final raw = entries[i];
    final originalId = _rawId(raw, 'id');
    final group = _EntryGroup(i + 1, originalId);
    groups.add(group);
    if (originalId != null) {
      owners.putIfAbsent(originalId, () => []).add(group);
    }
    try {
      final row = _object(raw, 'entries[${i + 1}]');
      final date = _date(row, 'date');
      final id = legacy && !row.containsKey('id')
          ? genId(prefix: 'e_')
          : _string(row, 'id', nonEmpty: true);
      final created = legacy && !row.containsKey('createdAt')
          ? date
          : _date(row, 'createdAt');
      final updated = legacy && !row.containsKey('updatedAt')
          ? date
          : _date(row, 'updatedAt');
      final tags = row.containsKey('tags')
          ? _array(row['tags'], 'tags')
          : const <dynamic>[];
      if (tags.any((tag) => tag is! String)) {
        throw const FormatException('tags 必须为字符串数组');
      }
      group.entry = Entry(
        id: id,
        date: date,
        task: _string(row, 'task'),
        context: _optionalString(row, 'context'),
        action: _optionalString(row, 'action'),
        result: _optionalString(row, 'result'),
        blocker: _optionalString(row, 'blocker'),
        tags: tags.cast<String>().toList(),
        createdAt: created,
        updatedAt: updated,
      );
      group.incomplete =
          legacy &&
          (originalId == null ||
              !row.containsKey('createdAt') ||
              !row.containsKey('updatedAt'));
    } on FormatException catch (error) {
      group.reasons.add(error.message);
    }
  }
  for (final duplicate in owners.values.where((list) => list.length > 1)) {
    for (final group in duplicate) {
      group.reasons.add('文件内记录 id 重复，无法确定引用归属');
    }
  }

  final questionOwners = <String, List<_QuestionRow>>{};
  for (var i = 0; i < questions.length; i++) {
    final raw = questions[i];
    final entryId = _rawId(raw, 'entryId');
    final matches = owners[entryId];
    final owner = matches != null && matches.length == 1
        ? matches.single
        : null;
    final id = _rawId(raw, 'id');
    if (id != null) {
      questionOwners.putIfAbsent(id, () => []).add(_QuestionRow(owner));
    }
    final prefix = 'questions[${i + 1}]';
    final reasons = <String>[];
    if (owner == null) {
      reasons.add('entryId 未指向本文件唯一记录（孤立或引用不明确）');
    }
    try {
      final row = _object(raw, prefix);
      final kind = _string(row, 'kind');
      final status = _string(row, 'status');
      if (!QuestionKind.values.any((value) => value.name == kind)) {
        throw FormatException('未知 kind：$kind');
      }
      if (!QuestionStatus.values.any((value) => value.name == status)) {
        throw FormatException('未知 status：$status');
      }
      final question = EvidenceQuestion(
        id: _string(row, 'id', nonEmpty: true),
        entryId: _string(row, 'entryId', nonEmpty: true),
        kind: QuestionKind.values.byName(kind),
        prompt: _string(row, 'prompt'),
        reason: _optionalString(row, 'reason'),
        status: QuestionStatus.values.byName(status),
        createdAt: _date(row, 'createdAt'),
        updatedAt: _date(row, 'updatedAt'),
      );
      owner?.questions.add(question);
    } on FormatException catch (error) {
      reasons.add(error.message);
    }
    if (reasons.isNotEmpty) {
      final reason = '$prefix：${reasons.join('；')}';
      if (owner == null) {
        issues.add(ImportIssue(source: source, index: i + 1, reason: reason));
      } else {
        owner.reasons.add(reason);
      }
    }
  }
  for (final duplicate in questionOwners.entries) {
    if (duplicate.value.length < 2) continue;
    for (final row in duplicate.value) {
      row.owner?.reasons.add('questions 的 id 重复：${duplicate.key}');
    }
  }

  final answerOwners = <String, List<_EntryGroup?>>{};
  for (var i = 0; i < answers.length; i++) {
    final raw = answers[i];
    final questionId = _rawId(raw, 'questionId');
    final matches = questionOwners[questionId];
    final owner = matches != null && matches.length == 1
        ? matches.single.owner
        : null;
    final id = _rawId(raw, 'id');
    if (id != null) {
      answerOwners.putIfAbsent(id, () => []).add(owner);
    }
    final prefix = 'answers[${i + 1}]';
    final reasons = <String>[];
    if (owner == null) {
      reasons.add('questionId 未指向本文件唯一且有归属的追问（孤立或引用不明确）');
    }
    try {
      final row = _object(raw, prefix);
      final answer = EvidenceAnswer(
        id: _string(row, 'id', nonEmpty: true),
        questionId: _string(row, 'questionId', nonEmpty: true),
        content: _string(row, 'content'),
        createdAt: _date(row, 'createdAt'),
      );
      owner?.answers.add(answer);
    } on FormatException catch (error) {
      reasons.add(error.message);
    }
    if (reasons.isNotEmpty) {
      final reason = '$prefix：${reasons.join('；')}';
      if (owner == null) {
        issues.add(ImportIssue(source: source, index: i + 1, reason: reason));
      } else {
        owner.reasons.add(reason);
      }
    }
  }
  for (final duplicate in answerOwners.entries) {
    if (duplicate.value.length < 2) continue;
    for (final owner in duplicate.value) {
      owner?.reasons.add('answers 的 id 重复：${duplicate.key}');
    }
  }

  final candidates = <ImportCandidate>[];
  for (final group in groups) {
    if (group.reasons.isNotEmpty) {
      issues.add(
        ImportIssue(
          source: source,
          index: group.index,
          reason: group.reasons.toSet().join('；'),
        ),
      );
      continue;
    }
    candidates.add(
      ImportCandidate(
        entry: group.entry!,
        questions: group.questions,
        answers: group.answers,
        hasOriginalId: group.originalId != null,
        incomplete: group.incomplete,
        legacy: legacy,
        source: source,
        index: group.index,
      ),
    );
  }
  return ParsedImport(candidates: candidates, issues: issues);
}

Map<String, dynamic> _object(dynamic value, String field) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$field 必须为对象');
  }
  return value;
}

List<dynamic> _array(dynamic value, String field) {
  if (value is! List) throw FormatException('$field 必须为数组');
  return value;
}

String? _rawId(dynamic row, String key) {
  if (row is! Map) return null;
  final id = row[key];
  return id is String && id.trim().isNotEmpty ? id : null;
}

String _string(Map<String, dynamic> row, String key, {bool nonEmpty = false}) {
  final value = row[key];
  if (value is! String || (nonEmpty && value.trim().isEmpty)) {
    throw FormatException('$key 必须为${nonEmpty ? '非空' : ''}字符串');
  }
  return value;
}

String _optionalString(Map<String, dynamic> row, String key) =>
    row.containsKey(key) ? _string(row, key) : '';

// DateTime.parse alone accepts impossible dates by rolling into the next month.
DateTime _date(Map<String, dynamic> row, String key) {
  final value = _string(row, key);
  final match = RegExp(
    r'^([+-]?\d{4,6})-(\d{2})-(\d{2})(?:[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?(?:[zZ]|[+-](\d{2}):?(\d{2}))?)?$',
  ).firstMatch(value);
  final parsed = DateTime.tryParse(value);
  if (match == null || parsed == null) {
    throw FormatException('$key 不是合法 ISO 8601 日期');
  }
  int part(int n) => int.parse(match.group(n) ?? '0');
  final year = part(1);
  final month = part(2);
  final day = part(3);
  final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  final monthDays = [
    31,
    leap ? 29 : 28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];
  // Do not construct midnight for this check: at Dart's date range boundary,
  // a valid offset timestamp can have an out-of-range UTC calendar midnight.
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > monthDays[month - 1] ||
      part(4) > 23 ||
      part(5) > 59 ||
      part(6) > 59 ||
      part(7) > 23 ||
      part(8) > 59) {
    throw FormatException('$key 不是合法日期或时间');
  }
  return parsed;
}
