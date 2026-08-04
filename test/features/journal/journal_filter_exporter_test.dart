import 'dart:convert';

import 'package:daily_asking/features/journal/application/journal_exporter.dart';
import 'package:daily_asking/features/journal/application/journal_filter.dart';
import 'package:daily_asking/features/journal/domain/entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final entries = [
    Entry(
      id: 'a',
      date: DateTime(2026, 8, 1, 10),
      task: '整理竞品价格页截图',
      context: '支持简历项目复盘',
      tags: const ['research'],
      createdAt: DateTime(2026, 8, 1, 10),
      updatedAt: DateTime(2026, 8, 1, 10),
    ),
    Entry(
      id: 'b',
      date: DateTime(2026, 8, 3, 10),
      task: '写周报',
      result: '形成周报草稿',
      tags: const ['report'],
      createdAt: DateTime(2026, 8, 3, 10),
      updatedAt: DateTime(2026, 8, 3, 10),
    ),
  ];

  test('filters entries by keyword and date range', () {
    final keywordResult = filterEntries(entries, const JournalFilter(query: '竞品'));
    expect(keywordResult.map((entry) => entry.id), ['a']);

    final rangeResult = filterEntries(
      entries,
      JournalFilter(startDate: DateTime(2026, 8, 2), endDate: DateTime(2026, 8, 4)),
    );
    expect(rangeResult.map((entry) => entry.id), ['b']);
  });

  test('exports selected entries without provider secrets or config', () {
    const exporter = JournalExporter();

    final markdown = exporter.toMarkdown([entries.first]);
    expect(markdown, contains('整理竞品价格页截图'));
    expect(markdown, isNot(contains('sk-test-secret')));
    expect(markdown, isNot(contains('daily_asking.llm_api_key.default')));

    final encoded = exporter.toJson([entries.first], exportedAt: DateTime(2026, 8, 4));
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    expect(decoded['schema'], 'daily_asking.entries.export.v1');
    expect(decoded['entries'], hasLength(1));
    expect(encoded, isNot(contains('sk-test-secret')));
    expect(encoded, isNot(contains('daily_asking.llm_api_key.default')));
  });
}
