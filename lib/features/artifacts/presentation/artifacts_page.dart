import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/llm/ai_provider_config.dart';
import '../../../core/llm/fake_llm_client.dart';
import '../../../core/llm/llm_client.dart';
import '../../../core/llm/openai_compatible_client.dart';
import '../../../core/prompts/prompt_registry.dart';
import '../../../core/security/ai_disclosure_policy.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/cosmic_scaffold.dart';
import '../../journal/application/journal_controller.dart';
import '../../journal/domain/entry.dart';
import '../../settings/application/ai_settings_controller.dart';
import '../application/artifact_generator.dart';
import '../domain/artifact.dart';

class ArtifactsPage extends ConsumerStatefulWidget {
  const ArtifactsPage({super.key});

  @override
  ConsumerState<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends ConsumerState<ArtifactsPage> {
  final _selectedIds = <String>{};
  ArtifactType _type = ArtifactType.resumeBullet;
  String? _result;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(journalControllerProvider).value ?? [];
    final config = ref.watch(aiSettingsControllerProvider).value;
    final selectedEntries = entries.where((entry) => _selectedIds.contains(entry.id)).toList();
    final textTheme = Theme.of(context).textTheme;

    return CosmicScaffold(
      child: ListView(
        children: [
          Text('AI 产物草稿', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            '先选择来源记录和产物类型。真实模型请求会在发送前再次确认，不会默认上传整个记录池。',
            style: textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _GenerationCard(
            type: _type,
            config: config,
            busy: _busy,
            selectedCount: selectedEntries.length,
            onTypeChanged: (value) => setState(() => _type = value),
            onGenerateReal: selectedEntries.isEmpty || _busy ? null : () => _generate(demo: false, config: config, entries: selectedEntries),
            onGenerateDemo: selectedEntries.isEmpty || _busy ? null : () => _generate(demo: true, config: config, entries: selectedEntries),
            onOpenSettings: () => context.go('/settings'),
          ),
          const SizedBox(height: 14),
          _SourcePicker(
            entries: entries,
            selectedIds: _selectedIds,
            onChanged: (id, selected) {
              setState(() {
                if (selected) {
                  _selectedIds.add(id);
                } else {
                  _selectedIds.remove(id);
                }
              });
            },
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

  Future<void> _generate({required bool demo, required AiProviderConfig? config, required List<Entry> entries}) async {
    if (!demo) {
      if (config == null || !config.isConfigured) {
        _showMessage('请先在设置中配置 BYOK 模型');
        return;
      }
      final confirmed = await _confirmOutbound(config, entries);
      if (!confirmed) return;
    }

    setState(() => _busy = true);
    try {
      final LlmClient client;
      final String model;
      if (demo) {
        client = FakeLlmClient();
        model = 'fake-model';
      } else {
        client = await _realClient(config!);
        model = config.model;
      }
      final generator = ArtifactGenerator(llmClient: client, promptRegistry: const PromptRegistry());
      final response = await generator.generate(_type, entries, model: model);
      if (mounted) {
        setState(() => _result = response.text);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _result = null);
        _showMessage('生成失败：$error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<LlmClient> _realClient(AiProviderConfig config) async {
    final apiKey = await ref.read(aiSettingsControllerProvider.notifier).readApiKey(config.keyAlias);
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const LlmException('未找到 API Key，请重新保存配置');
    }
    return OpenAiCompatibleClient(config: config, apiKey: apiKey);
  }

  Future<bool> _confirmOutbound(AiProviderConfig config, List<Entry> entries) async {
    final disclosure = const AiDisclosurePolicy().buildDisclosure(
      provider: '${config.providerName} / ${config.model}',
      fields: [
        '选中的 ${entries.length} 条记录',
        '任务、背景、行动、结果、卡点、标签',
        '${_type.label} prompt',
      ],
      throughGateway: false,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认发送给模型服务商？'),
        content: Text('$disclosure\n\n不会发送未选中的记录，也不会发送 API Key 明文。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('确认发送')),
        ],
      ),
    );
    return confirmed == true;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GenerationCard extends StatelessWidget {
  const _GenerationCard({
    required this.type,
    required this.config,
    required this.busy,
    required this.selectedCount,
    required this.onTypeChanged,
    required this.onGenerateReal,
    required this.onGenerateDemo,
    required this.onOpenSettings,
  });

  final ArtifactType type;
  final AiProviderConfig? config;
  final bool busy;
  final int selectedCount;
  final ValueChanged<ArtifactType> onTypeChanged;
  final VoidCallback? onGenerateReal;
  final VoidCallback? onGenerateDemo;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final configured = config != null && config!.isConfigured;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('生成设置', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          DropdownButtonFormField<ArtifactType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: '产物类型'),
            items: [
              for (final value in ArtifactType.values) DropdownMenuItem(value: value, child: Text(value.label)),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) onTypeChanged(value);
                  },
          ),
          const SizedBox(height: 12),
          Text('已选择 $selectedCount 条来源记录。'),
          const SizedBox(height: 8),
          Text(configured ? '真实模型：${config!.providerName} / ${config!.model}' : '未配置真实模型；可先使用演示生成，或去设置保存 BYOK。'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: configured ? onGenerateReal : null,
                icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high),
                label: Text(busy ? '生成中' : '真实模型生成'),
              ),
              OutlinedButton.icon(onPressed: onGenerateDemo, icon: const Icon(Icons.science), label: const Text('演示生成')),
              TextButton.icon(onPressed: onOpenSettings, icon: const Icon(Icons.tune), label: const Text('打开设置')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker({required this.entries, required this.selectedIds, required this.onChanged});

  final List<Entry> entries;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AppCard(child: Text('记录池为空。先在“今日”写入至少一条真实记录，再生成 AI 产物。'));
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('来源记录', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('只会发送勾选记录的任务、背景、行动、结果、卡点和标签。'),
          const SizedBox(height: 8),
          for (final entry in entries.take(20))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selectedIds.contains(entry.id),
              onChanged: (value) => onChanged(entry.id, value ?? false),
              title: Text(entry.task, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(entry.date.toIso8601String()),
            ),
          if (entries.length > 20) const Text('仅显示最近 20 条记录；请到记录池搜索并整理后再生成。'),
        ],
      ),
    );
  }
}
