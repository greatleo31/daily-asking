import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_provider_config.dart';
import 'llm_client.dart';

class OpenAiCompatibleClient implements LlmClient {
  OpenAiCompatibleClient({required this.config, required this.apiKey, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final AiProviderConfig config;
  final String apiKey;
  final http.Client _httpClient;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final endpoint = Uri.parse(config.baseUrl.replaceAll(RegExp(r'/+$'), '') + '/chat/completions');
    final response = await _httpClient.post(
      endpoint,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': request.model,
        'temperature': request.temperature,
        'max_tokens': request.maxTokens,
        'messages': request.messages.map((message) => message.toJson()).toList(),
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const LlmException('API Key 无效或没有权限');
    }
    if (response.statusCode == 429) {
      throw const LlmException('模型服务限流，请稍后再试');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException('模型服务返回 HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    final text = choices == null || choices.isEmpty
        ? ''
        : ((choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?)?['content'] as String? ?? '';
    if (text.trim().isEmpty) throw const LlmException('模型返回为空');
    return LlmResponse(text: text.trim(), model: request.model);
  }
}

class LlmException implements Exception {
  const LlmException(this.message);

  final String message;

  @override
  String toString() => message;
}
