import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entry.dart';

class EntryRepository {
  EntryRepository({Future<SharedPreferences> Function()? preferencesLoader})
      : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const storageKey = 'daily_asking.entries.v1';

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<List<Entry>> loadEntries() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => Entry.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } on Object catch (error) {
      throw EntryRepositoryException('本地记录数据无法解析，原始数据未被覆盖', cause: error);
    }
  }

  Future<void> saveEntries(List<Entry> entries) async {
    final prefs = await _preferencesLoader();
    final encoded = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    final saved = await prefs.setString(storageKey, encoded);
    if (!saved) {
      throw const EntryRepositoryException('本地记录保存失败');
    }
  }

  Future<void> addEntry(Entry entry) async {
    final current = await loadEntries();
    final next = [entry, ...current]..sort((a, b) => b.date.compareTo(a.date));
    await saveEntries(next);
  }

  Future<void> updateEntry(Entry entry) async {
    final current = await loadEntries();
    final index = current.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      throw const EntryRepositoryException('要更新的记录不存在');
    }
    final next = <Entry>[...current];
    next[index] = entry;
    next.sort((a, b) => b.date.compareTo(a.date));
    await saveEntries(next);
  }

  Future<void> deleteEntry(String id) async {
    final current = await loadEntries();
    final next = <Entry>[...current]..removeWhere((entry) => entry.id == id);
    await saveEntries(next);
  }
}

class EntryRepositoryException implements Exception {
  const EntryRepositoryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
