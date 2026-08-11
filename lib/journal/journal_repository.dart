/// 记录（journal）模块：Entry 的 Repository 与业务存取接口。
///
/// Repository 只依赖 [JsonStore] / [StorageService] 抽象，不感知具体存储实现。
library;

import '../core/models.dart';
import '../core/storage/storage.dart';

/// 记录存取接口，供页面与上层业务使用。
abstract class EntryRepository {
  Future<List<Entry>> list();
  Future<Entry?> find(String id);
  Future<void> save(Entry entry);
  Future<void> delete(String id);
}

/// 基于 JsonStore 的记录仓库实现。
class LocalEntryRepository implements EntryRepository {
  LocalEntryRepository(this._store);

  final JsonStore _store;
  static const _key = 'entries_v1';
  List<Entry> _cache = [];
  bool _loaded = false;

  Future<void> _ensure() async {
    if (_loaded) return;
    final rows = await _store.readList(_key);
    _cache = rows.map(Entry.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _loaded = true;
  }

  @override
  Future<List<Entry>> list() async {
    await _ensure();
    return List.of(_cache);
  }

  @override
  Future<Entry?> find(String id) async {
    await _ensure();
    for (final e in _cache) {
      if (e.id == id) return e.copy();
    }
    return null;
  }

  @override
  Future<void> save(Entry entry) async {
    await _ensure();
    final i = _cache.indexWhere((e) => e.id == entry.id);
    if (i >= 0) {
      _cache[i] = entry.copy();
    } else {
      _cache.add(entry.copy());
    }
    _cache.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _persist();
  }

  @override
  Future<void> delete(String id) async {
    await _ensure();
    _cache.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    await _store.writeList(_key, _cache.map((e) => e.toJson()).toList());
  }
}