/// 更新相关持久化（键与 docs/02-版本与更新机制.md 一致）。
library;

import '../core/storage/storage.dart';

/// 自动更新开关与上次检查时间的持久化。
class UpdatePrefs {
  UpdatePrefs(this._store);

  final StorageService _store;

  /// 自动更新开关统一存储键（默认关）。
  static const autoUpdateKey = 'lh.settings.autoUpdate';

  /// 「关于」页上次检查时间（ISO-8601）。
  static const lastCheckedAtKey = 'lastCheckedAt';

  Future<bool> isAutoUpdateEnabled() async {
    final v = await _store.readString(autoUpdateKey);
    return v == 'true';
  }

  Future<void> setAutoUpdateEnabled(bool enabled) async {
    await _store.writeString(autoUpdateKey, enabled ? 'true' : 'false');
  }

  Future<DateTime?> lastCheckedAt() async {
    final v = await _store.readString(lastCheckedAtKey);
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  Future<void> setLastCheckedAt(DateTime t) async {
    await _store.writeString(lastCheckedAtKey, t.toIso8601String());
  }
}