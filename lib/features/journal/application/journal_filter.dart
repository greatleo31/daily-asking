import '../domain/entry.dart';

class JournalFilter {
  const JournalFilter({
    this.query = '',
    this.startDate,
    this.endDate,
  });

  final String query;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isEmpty => query.trim().isEmpty && startDate == null && endDate == null;
}

List<Entry> filterEntries(List<Entry> entries, JournalFilter filter) {
  final normalizedQuery = filter.query.trim().toLowerCase();
  return entries.where((entry) {
    if (filter.startDate != null && entry.date.isBefore(_startOfDay(filter.startDate!))) {
      return false;
    }
    if (filter.endDate != null && entry.date.isAfter(_endOfDay(filter.endDate!))) {
      return false;
    }
    if (normalizedQuery.isEmpty) return true;
    return _searchableText(entry).contains(normalizedQuery);
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}

String _searchableText(Entry entry) {
  return [
    entry.task,
    entry.context,
    entry.action,
    entry.result,
    entry.blocker,
    ...entry.tags,
  ].join('\n').toLowerCase();
}

DateTime _startOfDay(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _endOfDay(DateTime value) => DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
