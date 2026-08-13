/// settings 模块：隐私边界与可选 BYOK AI 配置。
///
/// 隐私要求：
/// - API Key 只进入加密安全存储（flutter_secure_storage），不写入普通数据存储，
///   且不在页面回显；早期版本明文迁移后立即清除。
/// - 真实 AI 调用只发送当前用户选中的最小字段，且每次出站前必须确认。
library;

import 'dart:convert';

import '../core/storage/storage.dart';
import 'secure_key_store.dart';

/// 主题模式。
enum ThemeModePreference { system, light, dark }

/// BYOK AI 配置（不含 Key）。
class LlmSettings {
  LlmSettings({
    this.provider = '',
    this.baseUrl = '',
    this.model = '',
    this.enabled = false,
  });

  String provider; // 服务商名称
  String baseUrl; // OpenAI 兼容 base URL
  String model; // 模型名
  bool enabled;

  bool get isConfigured =>
      enabled && provider.isNotEmpty && baseUrl.isNotEmpty && model.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'baseUrl': baseUrl,
        'model': model,
        'enabled': enabled,
      };

  factory LlmSettings.fromJson(Map<String, dynamic> json) => LlmSettings(
        provider: json['provider'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        model: json['model'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? false,
      );
}

/// 设置仓库。
///
/// 隐私要求：API Key 只进入加密安全存储（flutter_secure_storage），
/// 普通 SharedPreferences 只保存非敏感设置（主题、服务商/模型等，不含 Key）。
class SettingsRepository {
  SettingsRepository(this._store, {SecureKeyValueStore? secure})
      : _secure = secure ?? FlutterSecureKeyValueStore();

  final StorageService _store;
  final SecureKeyValueStore _secure;
  static const _themeKey = 'settings_theme';
  static const _llmKey = 'settings_llm';
  static const _llmKeyKey = 'settings_llm_api_key';

  ThemeModePreference _theme = ThemeModePreference.system;
  LlmSettings _llm = LlmSettings();
  String _apiKey = '';
  bool _loaded = false;

  Future<void> _ensure() async {
    if (_loaded) return;
    final t = await _store.readString(_themeKey);
    _theme = ThemeModePreference.values
        .where((x) => x.name == t)
        .firstOrNull ?? ThemeModePreference.system;
    final lm = await _store.readString(_llmKey);
    if (lm != null) {
      _llm = LlmSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(lm) as Map));
    }
    // 迁移：早期版本把 Key 明文存在 SharedPreferences，读一次搬入安全存储后删除明文。
    final legacy = await _store.readString(_llmKeyKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _secure.write(_llmKeyKey, legacy);
      await _store.remove(_llmKeyKey);
    }
    _apiKey = await _secure.read(_llmKeyKey) ?? '';
    _loaded = true;
  }

  Future<ThemeModePreference> readTheme() async {
    await _ensure();
    return _theme;
  }

  Future<void> writeTheme(ThemeModePreference t) async {
    await _ensure();
    _theme = t;
    await _store.writeString(_themeKey, t.name);
  }

  Future<LlmSettings> readLlmSettings() async {
    await _ensure();
    return LlmSettings(
      provider: _llm.provider,
      baseUrl: _llm.baseUrl,
      model: _llm.model,
      enabled: _llm.enabled,
    );
  }

  /// 是否已配置 API Key（仅告知"有/无"，绝不回显内容）。
  Future<bool> hasApiKey() async {
    await _ensure();
    return _apiKey.isNotEmpty;
  }

  Future<void> writeLlmSettings(LlmSettings settings, {String? apiKey}) async {
    await _ensure();
    _llm = settings;
    await _store.writeString(_llmKey, jsonEncode(settings.toJson()));
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      _apiKey = apiKey.trim();
      await _secure.write(_llmKeyKey, _apiKey);
    }
  }

  /// 供真实 AI 调用时读取 Key（仅用于调用，绝不回显到 UI）。
  Future<String?> readApiKeyForCall() async {
    await _ensure();
    return _apiKey.isNotEmpty ? _apiKey : null;
  }

  Future<void> clearLlm() async {
    await _ensure();
    _llm = LlmSettings();
    _apiKey = '';
    await _store.remove(_llmKey);
    await _secure.delete(_llmKeyKey);
  }
}