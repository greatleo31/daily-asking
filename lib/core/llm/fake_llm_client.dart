import 'llm_client.dart';

class FakeLlmClient implements LlmClient {
  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return LlmResponse(
      model: request.model,
      text: '''{
  "usable_bullet": "负责整理并结构化记录当天工作事项，沉淀可复盘的项目经历素材。",
  "missing_fields": ["补充结果口径", "说明协作对象"],
  "interview_questions": ["这件事在项目里解决了什么问题？", "结果如何衡量？", "如果重做会优化哪里？"],
  "risk_notes": ["当前没有量化结果，不能编造数字"]
}''',
    );
  }
}
