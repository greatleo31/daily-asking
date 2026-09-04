/// 敏感值存储抽象：只存放 API Key 这类不能明文落盘的凭据。
///
/// 实现用 flutter_secure_storage（Android 走 Keystore +
/// EncryptedSharedPreferences，iOS/macOS 走 Keychain），
/// 满足「API Key 只进入安全存储」的隐私要求。
///
/// 版本说明：锁定 9.2.4（AndroidOptions.encryptedSharedPreferences 显式开启，
/// 且不需要 compileSdk 37；11.x 与当前 AGP 不兼容）。
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 加密存储的最小接口，便于测试注入假实现。
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// flutter_secure_storage 实现。
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  final FlutterSecureStorage _storage;

  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}