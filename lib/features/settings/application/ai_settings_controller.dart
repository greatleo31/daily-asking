import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/llm/ai_provider_config.dart';
import '../../../core/security/secure_vault.dart';

final secureVaultProvider = Provider<SecureVault>((ref) => SecureVault());

final aiSettingsControllerProvider =
    StateNotifierProvider<AiSettingsController, AsyncValue<AiProviderConfig?>>((ref) {
  return AiSettingsController(ref.watch(secureVaultProvider))..load();
});

class AiSettingsController extends StateNotifier<AsyncValue<AiProviderConfig?>> {
  AiSettingsController(this._vault) : super(const AsyncValue.loading());

  static const _configKey = 'daily_asking.ai_config.v1';
  static const _keyAlias = 'daily_asking.llm_api_key.default';

  final SecureVault _vault;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_configKey);
      if (raw == null || raw.isEmpty) return null;
      return AiProviderConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    });
  }

  Future<void> save({
    required String providerName,
    required String baseUrl,
    required String model,
    required String apiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey.trim().isNotEmpty) {
      await _vault.writeSecret(alias: _keyAlias, value: apiKey.trim());
    }
    final config = AiProviderConfig(
      providerName: providerName.trim().isEmpty ? 'OpenAI Compatible' : providerName.trim(),
      baseUrl: baseUrl.trim(),
      model: model.trim(),
      keyAlias: _keyAlias,
    );
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
    state = AsyncValue.data(config);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    await _vault.deleteSecret(_keyAlias);
    state = const AsyncValue.data(null);
  }

  Future<String?> readApiKey(String alias) {
    return _vault.readSecret(alias);
  }
}
