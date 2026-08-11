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

  static Future<SharedPrefsStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsStorage(prefs);
  }

  @override
  Future<String?> readString(String key) async => _prefs.getString(key);

  @override
  Future<void> writeString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
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