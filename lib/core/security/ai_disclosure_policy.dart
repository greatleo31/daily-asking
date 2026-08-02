class AiDisclosurePolicy {
  const AiDisclosurePolicy();

  String buildDisclosure({
    required String provider,
    required List<String> fields,
    required bool throughGateway,
  }) {
    final route = throughGateway ? '官方 AI 网关' : '你配置的模型服务商';
    return '本次会通过$route发送给 $provider：${fields.join('、')}。不会默认上传整个记录池。';
  }
}
