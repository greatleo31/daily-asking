import 'llm_client.dart';

class FakeLlmClient implements LlmClient {
  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final system = request.messages.isEmpty ? '' : request.messages.first.content;
    return LlmResponse(model: request.model, text: _fakeJson(system));
  }

  String _fakeJson(String system) {
    if (system.contains('实习周报')) {
      return '''{
  "summary": "本周围绕真实工作记录完成素材整理和复盘。",
  "sections": [{"theme": "记录与复盘", "bullets": ["整理本周工作事项，标记仍需补充的结果口径。"]}],
  "missing_fields": ["补充可量化结果", "确认项目名称是否可公开"]
}''';
    }
    if (system.contains('面试追问')) {
      return '''{
  "opening_answer": "我基于真实记录整理了任务背景、行动和结果，但量化结果仍需补证据。",
  "questions": [{"question": "这件事的结果如何衡量？", "answer_angle": "只回答原始记录中已有结果，缺失指标时说明待补充。"}],
  "evidence_gaps": ["缺少量化指标", "缺少协作对象"]
}''';
    }
    if (system.contains('提出 3-5 个')) {
      return '''{
  "questions": [{"question": "这件事在项目里解决了什么问题？", "reason": "补足背景和业务价值。"}, {"question": "结果如何衡量？", "reason": "避免编造指标。"}],
  "risk_notes": ["当前记录不足以生成确定成果"]
}''';
    }
    return '''{
  "usable_bullet": "负责整理并结构化记录当天工作事项，沉淀可复盘的项目经历素材。",
  "missing_fields": ["补充结果口径", "说明协作对象"],
  "interview_questions": ["这件事在项目里解决了什么问题？", "结果如何衡量？", "如果重做会优化哪里？"],
  "risk_notes": ["当前没有量化结果，不能编造数字"]
}''';
  }
}
