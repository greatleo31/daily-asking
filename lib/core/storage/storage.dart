/// 本地存储抽象。
///
/// 当前实现将整个数据集序列化为 JSON 保存在 SharedPreferences；
/// 接口保持与持久化方案解耦，后续可无缝替换为 SQLite / Drift 实现。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 存储服务接口：Repository 只依赖此抽象，不依赖具体持久化技术。
abstract class StorageService {
  Future<String?> readString(String key);
  Future<void> writeString(String key, String value);
  Future<void> remove(String key);
}

/// 基于 SharedPreferences 的轻量 JSON 存储实现。
class SharedPrefsStorage implements StorageService {
  SharedPrefsStorage(this._prefs);

  final SharedPreferences _prefs;

  // 插件会先修改 Dart 缓存再等待原生确认；不能把该缓存当作落盘证明。
  // 同一 prefs singleton 的所有包装器共享隔离状态，reload 也不能解除。
  static final _uncertainWrites = Expando<Map<String, _PreferenceWriteState>>();

  Map<String, _PreferenceWriteState> get _uncertain =>
      _uncertainWrites[_prefs] ??= <String, _PreferenceWriteState>{};

  static Future<SharedPrefsStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsStorage(prefs);
  }

  @override
  Future<String?> readString(String key) async {
    if (_uncertain.containsKey(key)) {
      throw StateError('本地数据写入状态未确认，请重启应用后核对数据');
    }
    return _prefs.getString(key);
  }

  @override
  Future<void> writeString(String key, String value) =>
      _confirmedMutation(key, () => _prefs.setString(key, value));

  @override
  Future<void> remove(String key) =>
      _confirmedMutation(key, () => _prefs.remove(key));

  Future<void> _confirmedMutation(
    String key,
    Future<bool> Function() mutate,
  ) async {
    final uncertain = _uncertain;
    final state = uncertain.putIfAbsent(key, _PreferenceWriteState.new);
    final attempt = Object();
    state.latest = attempt;
    state.pending++;
    try {
      if (!await mutate()) throw StateError('本地数据写入失败');
      // 只认可最后一次操作的确认，且不能有别的同 key 操作仍在进行。
      // 乱序完成时宁可保持隔离，等待一次独立的成功重试。
      if (state.pending == 1 && identical(state.latest, attempt)) {
        uncertain.remove(key);
      }
    } finally {
      state.pending--;
      // false / throw 保留隔离标记；绝不靠 reload 推断真实落盘状态。
    }
  }
}

class _PreferenceWriteState {
  Object? latest;
  int pending = 0;
}

/// 简单 JSON 文档袋：把多个列表以 JSON 字符串存到存储服务。
class JsonStore {
  JsonStore(this._storage);

  final StorageService _storage;

  Future<List<Map<String, dynamic>>> readList(String key) async {
    final raw = await _storage.readString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> list) async {
    await _storage.writeString(key, jsonEncode(list));
  }

  Future<Map<String, dynamic>?> readMap(String key) async {
    final raw = await _storage.readString(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    await _storage.writeString(key, jsonEncode(value));
  }

  Future<void> remove(String key) async => _storage.remove(key);
}
