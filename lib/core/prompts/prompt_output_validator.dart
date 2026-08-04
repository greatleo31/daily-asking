import 'dart:convert';

import 'prompt_registry.dart';

class PromptOutputValidator {
  const PromptOutputValidator();

  Map<String, dynamic> validate(PromptTemplate prompt, String rawOutput) {
    final decoded = _decodeObject(rawOutput);
    final requiredFields = (prompt.outputContract['required'] as List<dynamic>? ?? const []).cast<String>();
    for (final field in requiredFields) {
      if (!decoded.containsKey(field)) {
        throw PromptOutputContractException('模型输出缺少字段：$field');
      }
      _validateProperty(field, decoded[field], prompt.outputContract['properties']);
    }
    return decoded;
  }

  Map<String, dynamic> _decodeObject(String rawOutput) {
    try {
      final decoded = jsonDecode(rawOutput.trim());
      if (decoded is Map<String, dynamic>) return decoded;
      throw const PromptOutputContractException('模型输出不是 JSON object');
    } on PromptOutputContractException {
      rethrow;
    } on Object {
      throw const PromptOutputContractException('模型输出不是合法 JSON');
    }
  }

  void _validateProperty(String field, Object? value, Object? properties) {
    if (properties is! Map<String, dynamic>) return;
    final property = properties[field];
    if (property is! Map<String, dynamic>) return;
    final type = property['type'];
    if (type == 'string' && value is! String) {
      throw PromptOutputContractException('模型输出字段 $field 必须是 string');
    }
    if (type == 'array') {
      if (value is! List) {
        throw PromptOutputContractException('模型输出字段 $field 必须是 array');
      }
      final itemType = (property['items'] as Map<String, dynamic>?)?['type'];
      if (itemType == 'string' && value.any((item) => item is! String)) {
        throw PromptOutputContractException('模型输出字段 $field 必须是 string array');
      }
      if (itemType == 'object' && value.any((item) => item is! Map<String, dynamic>)) {
        throw PromptOutputContractException('模型输出字段 $field 必须是 object array');
      }
    }
  }
}

class PromptOutputContractException implements Exception {
  const PromptOutputContractException(this.message);

  final String message;

  @override
  String toString() => message;
}
