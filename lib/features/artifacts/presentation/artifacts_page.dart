import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/llm/fake_llm_client.dart';
import '../../../core/prompts/prompt_registry.dart';
import '../../../core/security/ai_disclosure_policy.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/cosmic_scaffold.dart';
import '../../journal/application/journal_controller.dart';
import '../../journal/domain/entry.dart';
import '../application/artifact_generator.dart';

class ArtifactsPage extends ConsumerStatefulWidget {
  const ArtifactsPage({super.key});

  @override
  ConsumerState<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends ConsumerState<ArtifactsPage> {
  String? _result;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(journalControllerProvider).value ?? [];
    final textTheme = Theme.of(context).textTheme;

    return CosmicScaffold(
      child: ListView(
        children: [
          Text('AI 产物草稿', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            const AiDisclosurePolicy().buildDisclosure(
              provider: 'Fake LLM / BYOK Provider',
              fields: const ['当前选中记录', '已填写的背景、行动、结果、卡点'],
              throughGateway: false,
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('简历 bullet', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text('第一版先使用 fake client 串通流程；配置 BYOK 后可替换为真实模型。'),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: entries.isEmpty || _busy ? null : () => _generate(entries.first),
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_fix_high),
                  label: Text(_busy ? '生成中' : '基于最新记录生成'),
                ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('草稿结果', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  SelectableText(_result!),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Clipboard.setData(ClipboardData(text: _result!)),
                    icon: const Icon(Icons.copy),
                    label: const Text('复制'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generate(Entry entry) async {
    setState(() => _busy = true);
    final generator = ArtifactGenerator(
      llmClient: FakeLlmClient(),
      promptRegistry: const PromptRegistry(),
    );
    try {
      final response = await generator.generateResumeBullet(entry, model: 'fake-model');
      setState(() => _result = response.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
