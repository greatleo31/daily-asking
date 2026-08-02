import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/cosmic_scaffold.dart';
import '../application/ai_settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _provider = TextEditingController(text: 'OpenAI Compatible');
  final _baseUrl = TextEditingController(text: 'https://api.example.com/v1');
  final _model = TextEditingController(text: 'your-model-name');
  final _key = TextEditingController();

  @override
  void dispose() {
    _provider.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(aiSettingsControllerProvider).value;
    final textTheme = Theme.of(context).textTheme;

    return CosmicScaffold(
      child: ListView(
        children: [
          Text('设置', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BYOK 模型配置', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text('API Key 只写入系统安全存储；页面不会保存明文 Key 到数据库。'),
                const SizedBox(height: 14),
                TextField(controller: _provider, decoration: const InputDecoration(labelText: 'Provider 名称')),
                const SizedBox(height: 12),
                TextField(controller: _baseUrl, decoration: const InputDecoration(labelText: 'Base URL')),
                const SizedBox(height: 12),
                TextField(controller: _model, decoration: const InputDecoration(labelText: 'Model')),
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'API Key', hintText: 'sk-...'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FilledButton(onPressed: _save, child: const Text('保存配置')),
                    const SizedBox(width: 10),
                    OutlinedButton(onPressed: _clear, child: const Text('清除')),
                  ],
                ),
                const SizedBox(height: 12),
                Text(config == null ? '当前未配置真实模型，产物页使用 fake client。' : '已配置：${config.providerName} / ${config.model}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    await ref.read(aiSettingsControllerProvider.notifier).save(
          providerName: _provider.text,
          baseUrl: _baseUrl.text,
          model: _model.text,
          apiKey: _key.text,
        );
    _key.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI 配置已保存')));
    }
  }

  Future<void> _clear() async {
    await ref.read(aiSettingsControllerProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI 配置已清除')));
    }
  }
}
