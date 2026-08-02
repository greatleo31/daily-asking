import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureVault {
  SecureVault({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> writeSecret({required String alias, required String value}) async {
    await _storage.write(key: alias, value: value);
  }

  Future<String?> readSecret(String alias) {
    return _storage.read(key: alias);
  }

  Future<void> deleteSecret(String alias) {
    return _storage.delete(key: alias);
  }
}
