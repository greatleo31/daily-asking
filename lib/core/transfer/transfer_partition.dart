import 'dart:convert';

import 'transfer_schema.dart';

const maxTransferFileBytes = 10 * 1024 * 1024;

class TransferPartitionException implements Exception {
  const TransferPartitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Independently importable v2 files; a record and its children stay together.
///
/// Entry order is preserved. Each part's child arrays are subsequences of the
/// original arrays, preserving their relative order even when input children
/// are interleaved across entries. No source model or list is mutated.
///
/// Every row is encoded once. ID indexes, group sizes and a second linear pass
/// over children avoid re-encoding growing parts or rescanning all children for
/// each entry: O(entries + questions + answers + encoded bytes).
List<String> encodeTransferParts(
  TransferData data, {
  required DateTime exportedAt,
  required String appVersion,
  int maxEntries = maxImportEntries,
  int maxBytes = maxTransferFileBytes,
}) {
  if (maxEntries < 1 || maxEntries > maxImportEntries) {
    throw const TransferPartitionException('分片记录上限必须为 1 至 5000');
  }
  if (maxBytes < 1 || maxBytes > maxTransferFileBytes) {
    throw const TransferPartitionException('分片文件大小上限必须大于 0 且不超过 10 MB');
  }

  // Keep exactly the existing seven top-level keys, with compact JSON. These
  // fragments include every delimiter except commas between array elements.
  final prefix =
      '{"schema":${jsonEncode(transferSchemaV2)},"schemaVersion":2,'
      '"exportedAt":${jsonEncode(exportedAt.toIso8601String())},'
      '"appVersion":${jsonEncode(appVersion)},"entries":[';
  const questionsStart = '],"questions":[';
  const answersStart = '],"answers":[';
  const suffix = ']}';
  final overhead = utf8
      .encode(prefix + questionsStart + answersStart + suffix)
      .length;

  final groups = <_EntryGroup>[];
  final entryIndex = <String, _EntryGroup>{};
  for (final entry in data.entries) {
    _checkId(entry.id, '记录');
    if (entryIndex.containsKey(entry.id)) {
      throw TransferPartitionException('记录 id 重复，无法安全分片导出：${entry.id}');
    }
    final group = _EntryGroup(_EncodedRow(entry.toJson()));
    groups.add(group);
    entryIndex[entry.id] = group;
  }

  final questionIndex = <String, _EntryGroup>{};
  final questions = <_ChildRow>[];
  for (final question in data.questions) {
    _checkId(question.id, '追问');
    if (questionIndex.containsKey(question.id)) {
      throw TransferPartitionException('追问 id 重复，无法安全分片导出：${question.id}');
    }
    final owner = entryIndex[question.entryId];
    if (owner == null) {
      throw TransferPartitionException('追问 ${question.id} 未关联到导出记录，无法安全分片导出');
    }
    final row = _EncodedRow(question.toJson());
    questionIndex[question.id] = owner;
    questions.add(_ChildRow(owner, row));
    owner.questionCount++;
    owner.rowBytes += row.bytes;
  }

  final answerIds = <String>{};
  final answers = <_ChildRow>[];
  for (final answer in data.answers) {
    _checkId(answer.id, '回答');
    if (!answerIds.add(answer.id)) {
      throw TransferPartitionException('回答 id 重复，无法安全分片导出：${answer.id}');
    }
    final owner = questionIndex[answer.questionId];
    if (owner == null) {
      throw TransferPartitionException('回答 ${answer.id} 未关联到导出追问，无法安全分片导出');
    }
    final row = _EncodedRow(answer.toJson());
    answers.add(_ChildRow(owner, row));
    owner.answerCount++;
    owner.rowBytes += row.bytes;
  }

  if (overhead > maxBytes) {
    throw const TransferPartitionException('导出元信息超过文件大小上限，无法分片导出');
  }
  final parts = <_Part>[_Part()];
  for (final group in groups) {
    final groupBytes =
        overhead +
        group.rowBytes +
        _commas(group.questionCount) +
        _commas(group.answerCount);
    if (groupBytes > maxBytes) {
      final limit = maxBytes == maxTransferFileBytes ? '10 MB' : '$maxBytes 字节';
      throw TransferPartitionException('单条记录及其追问回答超过 $limit，无法分片导出');
    }
    var part = parts.last;
    if (part.entries.length == maxEntries ||
        part.sizeWith(group, overhead) > maxBytes) {
      part = _Part();
      parts.add(part);
    }
    group.part = parts.length - 1;
    part.entries.add(group.entry.text);
    part.rowBytes += group.rowBytes;
    part.questionCount += group.questionCount;
    part.answerCount += group.answerCount;
  }

  // Assign children in their ORIGINAL order, rather than concatenating per-
  // entry groups, which would unnecessarily reorder interleaved child rows.
  for (final question in questions) {
    parts[question.owner.part].questions.add(question.row.text);
  }
  for (final answer in answers) {
    parts[answer.owner.part].answers.add(answer.row.text);
  }
  return [
    for (final part in parts)
      '$prefix${part.entries.join(',')}'
          '$questionsStart${part.questions.join(',')}'
          '$answersStart${part.answers.join(',')}$suffix',
  ];
}

void _checkId(String id, String kind) {
  if (id.trim().isEmpty) {
    throw TransferPartitionException('$kind缺少有效 id，无法安全分片导出');
  }
}

int _commas(int count) => count > 0 ? count - 1 : 0;

class _EncodedRow {
  _EncodedRow(Map<String, dynamic> row) : text = jsonEncode(row) {
    bytes = utf8.encode(text).length;
  }

  final String text;
  late final int bytes;
}

class _EntryGroup {
  _EntryGroup(this.entry) : rowBytes = entry.bytes;

  final _EncodedRow entry;
  int rowBytes;
  int questionCount = 0;
  int answerCount = 0;
  int part = 0;
}

class _ChildRow {
  _ChildRow(this.owner, this.row);

  final _EntryGroup owner;
  final _EncodedRow row;
}

class _Part {
  final entries = <String>[];
  final questions = <String>[];
  final answers = <String>[];
  int rowBytes = 0;
  int questionCount = 0;
  int answerCount = 0;

  int sizeWith(_EntryGroup group, int overhead) =>
      overhead +
      rowBytes +
      group.rowBytes +
      _commas(entries.length + 1) +
      _commas(questionCount + group.questionCount) +
      _commas(answerCount + group.answerCount);
}
