import 'package:daily_asking/core/logging/safe_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redacts sensitive fields and suspicious values from debug logs', () {
    final messages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      messages.add(message ?? '');
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    const SafeLogger().info(
      'event',
      fields: {
        'note': 'ok',
        'apiKey': 'sk-test-secret',
        'token': 'token-value',
        'prompt': 'full prompt',
        'providerResponse': List.filled(501, 'x').join(),
      },
    );

    expect(messages.single, contains('note: ok'));
    expect(messages.single, isNot(contains('sk-test-secret')));
    expect(messages.single, isNot(contains('token-value')));
    expect(messages.single, isNot(contains('full prompt')));
    expect(messages.single, isNot(contains('providerResponse')));
  });
}
