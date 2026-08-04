import 'package:daily_asking/core/security/secure_vault.dart';
import 'package:daily_asking/features/settings/application/ai_settings_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('stores API key in secure storage and removes it when cleared', () async {
    final controller = AiSettingsController(SecureVault());

    await controller.save(
      providerName: 'OpenAI Compatible',
      baseUrl: 'https://api.example.com/v1',
      model: 'demo-model',
      apiKey: 'sk-test-secret',
    );

    final config = controller.state.value;
    expect(config, isNotNull);
    expect(config!.keyAlias, isNotEmpty);
    expect(await controller.readApiKey(config.keyAlias), 'sk-test-secret');

    await controller.clear();

    expect(controller.state.value, isNull);
    expect(await controller.readApiKey(config.keyAlias), isNull);
  });
}

