import 'package:daily_asking/core/llm/llm_client.dart';
import 'package:daily_asking/core/prompts/prompt_registry.dart';
import 'package:daily_asking/features/artifacts/application/artifact_generator.dart';
import 'package:daily_asking/features/artifacts/domain/artifact.dart';
import 'package:daily_asking/features/journal/domain/entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rejects generated numeric metrics that are not in source records', () async {
    const generator = ArtifactGenerator(
      llmClient: _StaticLlmClient('''{
  "usable_bullet": "推动整理工作并提升 30% 效率。",
  "missing_fields": [],
  "interview_questions": [],
  "risk_notes": []
}'''),
      promptRegistry: PromptRegistry(),
    );
    final entry = Entry(
      id: 'entry-1',
      date: DateTime(2026, 8, 1),
      task: '整理竞品价格页截图',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );

    await expectLater(
      generator.generate(ArtifactType.resumeBullet, [entry], model: 'fake'),
      throwsA(isA<ArtifactGenerationException>()),
    );
  });
}

class _StaticLlmClient implements LlmClient {
  const _StaticLlmClient(this.text);

  final String text;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    return LlmResponse(text: text, model: request.model);
  }
}
