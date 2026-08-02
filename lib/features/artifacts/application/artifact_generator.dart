import '../../../core/llm/llm_client.dart';
import '../../../core/prompts/prompt_registry.dart';
import '../../journal/domain/entry.dart';

class ArtifactGenerator {
  const ArtifactGenerator({required this.llmClient, required this.promptRegistry});

  final LlmClient llmClient;
  final PromptRegistry promptRegistry;

  Future<LlmResponse> generateResumeBullet(Entry entry, {required String model}) async {
    final prompt = await promptRegistry.load('resume_bullet');
    return llmClient.complete(
      LlmRequest(
        model: model,
        messages: [
          LlmMessage(role: 'system', content: prompt.system),
          LlmMessage(
            role: 'user',
            content: '''
任务：${entry.task}
背景：${entry.context}
行动：${entry.action}
结果：${entry.result}
卡点：${entry.blocker}

请严格输出 JSON，不要 markdown。
''',
          ),
        ],
      ),
    );
  }
}
