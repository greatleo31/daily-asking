class LlmMessage {
  const LlmMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class LlmRequest {
  const LlmRequest({
    required this.model,
    required this.messages,
    this.temperature = 0.2,
    this.maxTokens = 900,
  });

  final String model;
  final List<LlmMessage> messages;
  final double temperature;
  final int maxTokens;
}

class LlmResponse {
  const LlmResponse({required this.text, required this.model});

  final String text;
  final String model;
}

abstract interface class LlmClient {
  Future<LlmResponse> complete(LlmRequest request);
}
