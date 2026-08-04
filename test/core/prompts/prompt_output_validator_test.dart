import 'package:daily_asking/core/prompts/prompt_output_validator.dart';
import 'package:daily_asking/core/prompts/prompt_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads all production prompt contracts', () async {
    const registry = PromptRegistry();

    for (final id in ['follow_up', 'resume_bullet', 'weekly_report', 'interview_card']) {
      final prompt = await registry.load(id);
      expect(prompt.id, id);
      expect(prompt.outputContract['type'], 'object');
      expect(prompt.outputContract['required'], isA<List<dynamic>>());
    }
  });

  test('validates required fields and primitive contract types', () {
    const validator = PromptOutputValidator();
    const prompt = PromptTemplate(
      id: 'test_prompt',
      version: 1,
      schemaVersion: 1,
      system: 'test',
      outputContract: {
        'type': 'object',
        'required': ['summary', 'items'],
        'properties': {
          'summary': {'type': 'string'},
          'items': {'type': 'array', 'items': {'type': 'string'}},
        },
      },
    );

    final decoded = validator.validate(prompt, '{"summary":"ok","items":["a"]}');
    expect(decoded['summary'], 'ok');

    expect(
      () => validator.validate(prompt, '{"summary":"ok"}'),
      throwsA(isA<PromptOutputContractException>()),
    );
    expect(
      () => validator.validate(prompt, '{"summary":"ok","items":"bad"}'),
      throwsA(isA<PromptOutputContractException>()),
    );
    expect(
      () => validator.validate(prompt, 'not-json'),
      throwsA(isA<PromptOutputContractException>()),
    );
  });
}
