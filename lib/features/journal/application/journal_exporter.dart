import 'dart:convert';

import 'package:intl/intl.dart';

import '../domain/entry.dart';

class JournalExporter {
  const JournalExporter();

  String toMarkdown(List<Entry> entries) {
    final buffer = StringBuffer()
      ..writeln('# Daily Asking 记录导出')
      ..writeln()
      ..writeln('- 记录数：${entries.length}')
      ..writeln('- 说明：本导出只包含用户记录字段，不包含 API Key、模型凭据、日志或安全存储信息。')
      ..writeln();
    for (final entry in entries) {
      buffer
        ..writeln('## ${_dateTime.format(entry.date)} - ${_sanitizeLine(entry.task)}')
        ..writeln()
        ..writeln('- ID：${entry.id}')
        ..writeln('- 背景：${_emptyAsDash(entry.context)}')
        ..writeln('- 行动：${_emptyAsDash(entry.action)}')
        ..writeln('- 结果：${_emptyAsDash(entry.result)}')
        ..writeln('- 卡点/复盘：${_emptyAsDash(entry.blocker)}')
        ..writeln('- 标签：${entry.tags.isEmpty ? '-' : entry.tags.join(', ')}')
        ..writeln('- 创建时间：${entry.createdAt.toIso8601String()}')
        ..writeln('- 更新时间：${entry.updatedAt.toIso8601String()}')
        ..writeln();
    }
    return buffer.toString().trimRight();
  }

  String toJson(List<Entry> entries, {DateTime? exportedAt}) {
    return const JsonEncoder.withIndent('  ').convert({
      'schema': 'daily_asking.entries.export.v1',
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
    });
  }

  static final _dateTime = DateFormat('yyyy-MM-dd HH:mm');

  String _emptyAsDash(String value) => value.trim().isEmpty ? '-' : value.trim();

  String _sanitizeLine(String value) => value.replaceAll('\n', ' ').trim();
}
