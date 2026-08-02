import 'package:flutter/foundation.dart';

class SafeLogger {
  const SafeLogger();

  void info(String message, {Map<String, Object?> fields = const {}}) {
    if (!kDebugMode) return;
    final safeFields = Map<String, Object?>.from(fields)
      ..removeWhere((key, value) => _isSensitive(key) || _looksSensitive(value));
    debugPrint('[DailyAsking] $message $safeFields');
  }

  bool _isSensitive(String key) {
    final lower = key.toLowerCase();
    return lower.contains('key') || lower.contains('token') || lower.contains('secret') || lower.contains('prompt');
  }

  bool _looksSensitive(Object? value) {
    if (value is! String) return false;
    return value.startsWith('sk-') || value.length > 500;
  }
}
