class AiProviderConfig {
  const AiProviderConfig({
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.keyAlias,
  });

  final String providerName;
  final String baseUrl;
  final String model;
  final String keyAlias;

  bool get isConfigured => baseUrl.isNotEmpty && model.isNotEmpty && keyAlias.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'providerName': providerName,
        'baseUrl': baseUrl,
        'model': model,
        'keyAlias': keyAlias,
      };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) {
    return AiProviderConfig(
      providerName: json['providerName'] as String? ?? 'OpenAI Compatible',
      baseUrl: json['baseUrl'] as String? ?? '',
      model: json['model'] as String? ?? '',
      keyAlias: json['keyAlias'] as String? ?? '',
    );
  }
}
