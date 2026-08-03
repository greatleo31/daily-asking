import '../../../core/llm/llm_client.dart';
import '../../../core/prompts/prompt_output_validator.dart';
import '../../../core/prompts/prompt_registry.dart';
import '../../journal/domain/entry.dart';
import '../domain/artifact.dart';

class ArtifactGenerator {
  const ArtifactGenerator({
    required this.llmClient,
    required this.promptRegistry,
    this.outputValidator = const PromptOutputValidator(),
  });

  final LlmClient llmClient;
  final PromptRegistry promptRegistry;
  final PromptOutputValidator outputValidator;

  Future<LlmResponse> generate(ArtifactType type, List<Entry> entries, {required String model}) async {
    if (entries.isEmpty) {
      throw const ArtifactGenerationException('请选择至少一条来源记录');
    }
    final prompt = await promptRegistry.load(type.promptId);
    final response = await llmClient.complete(
      LlmRequest(
        model: model,
        maxTokens: type == ArtifactType.weeklyReport ? 1400 : 900,
        messages: [
          LlmMessage(role: 'system', content: prompt.system),
          LlmMessage(
            role: 'user',
            content: '''
产物类型：${type.label}
来源记录：
${_sourcePayload(entries)}

请严格输出 JSON，不要 markdown。
''',
          ),
        ],
      ),
    );
    outputValidator.validate(prompt, response.text);
    _throwIfUnsupportedNumbers(response.text, entries);
    return response;
  }

  Future<LlmResponse> generateResumeBullet(Entry entry, {required String model}) {
    return generate(ArtifactType.resumeBullet, [entry], model: model);
  }

  void _throwIfUnsupportedNumbers(String output, List<Entry> entries) {
    final sourceText = entries
        .map(
          (entry) => [
            entry.task,
            entry.context,
            entry.action,
            entry.result,
            entry.blocker,
            ...entry.tags,
          ].join(' '),
        )
        .join(' ');
    final sourceNumbers = _numbers(sourceText);
    final unsupported = _numbers(output).where((number) => !sourceNumbers.contains(number)).toSet();
    if (unsupported.isNotEmpty) {
      throw ArtifactGenerationException('模型输出包含来源记录未提供的数字：${unsupported.join(', ')}');
    }
  }

  Set<String> _numbers(String value) {
    return RegExp(r'\d+(?:[.,]\d+)?%?').allMatches(value).map((match) => match.group(0)!).toSet();
  }

  String _sourcePayload(List<Entry> entries) {
    return entries.indexed.map((item) {
      final index = item.$1 + 1;
      final entry = item.$2;
      return '''
[$index]
日期：${entry.date.toIso8601String()}
任务：${entry.task}
背景：${entry.context}
行动：${entry.action}
结果：${entry.result}
卡点：${entry.blocker}
标签：${entry.tags.join(', ')}
''';
    }).join('\n');
  }
}

class ArtifactGenerationException implements Exception {
  const ArtifactGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
