/// 设置：本地优先与隐私边界 + 可选 BYOK AI 配置 + 主题切换。
///
/// API Key 不回显、不写普通数据库；提供清除配置按钮。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import 'settings_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('设置',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _PrivacyCard(),
          const SizedBox(height: 16),
          Text('外观',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<ThemeModePreference>(
              groupValue: _theme,
              onChanged: (v) => _setTheme(v, state),
              child: Column(
                children: [
                  RadioListTile<ThemeModePreference>(
                    title: const Text('跟随系统'),
                    value: ThemeModePreference.system,
                  ),
                  RadioListTile<ThemeModePreference>(
                    title: const Text('亮色'),
                    value: ThemeModePreference.light,
                  ),
                  RadioListTile<ThemeModePreference>(
                    title: const Text('深色'),
                    value: ThemeModePreference.dark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('可选 AI（BYOK）',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        state.aiReady ? '已配置' : '未配置',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: state.aiReady
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _configureAi(context),
                        child: Text(state.aiReady ? '修改' : '配置'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.aiReady
                        ? '服务商：${state.llmSettings.provider} · '
                            '模型：${state.llmSettings.model}'
                        : '可选择 OpenAI 兼容服务，用于把证据整理成简历/周报/面试卡。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  if (state.aiReady) ...[
                    const SizedBox(height: 8),
                    Text('API Key：已保存（不显示）',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.secondary)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _clearAi,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('清除 AI 配置'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB8452F),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('关于',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('晨昏证据图谱'),
              subtitle: const Text('本地优先职场证据成长助手 · v1.0.0'),
            ),
          ),
        ],
      ),
    );
  }

  ThemeModePreference get _theme {
    return context.watch<AppState>().theme;
  }

  Future<void> _setTheme(ThemeModePreference? v, AppState state) async {
    if (v == null) return;
    await state.setTheme(v);
  }

  Future<void> _configureAi(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiConfigPage()),
    );
  }

  Future<void> _clearAi() async {
    final state = context.read<AppState>();
    await state.settings.clearLlm();
    await state.reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已清除 AI 配置')));
  }
}

class _PrivacyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('本地优先 · 隐私边界',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            _privacyRow(theme, '所有记录默认保存在本机，不出设备。'),
            _privacyRow(theme, '无账号、无登录、无订阅、无云同步、无遥测。'),
            _privacyRow(theme, '真实 AI 调用只发送你选中的最小字段，且出站前确认。'),
            _privacyRow(theme, '日志不记录 API Key、记录正文与提示词全文。'),
          ],
        ),
      ),
    );
  }

  Widget _privacyRow(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// AI 配置页。API Key 输入不回显（obscure），保存后仅存隔离存储。
class AiConfigPage extends StatefulWidget {
  const AiConfigPage({super.key});

  @override
  State<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends State<AiConfigPage> {
  final _provider = TextEditingController();
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  final _apiKeyVisible = ValueNotifier<bool>(false);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final s = await state.settings.readLlmSettings();
    if (!mounted) return;
    _provider.text = s.provider;
    _baseUrl.text = s.baseUrl;
    _model.text = s.model;
    // API Key 不回显。
  }

  @override
  void dispose() {
    _provider.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    _apiKeyVisible.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    setState(() => _busy = true);
    final settings = LlmSettings(
      provider: _provider.text.trim(),
      baseUrl: _baseUrl.text.trim(),
      model: _model.text.trim(),
      enabled: true,
    );
    final key = _apiKey.text.trim().isEmpty
        ? null
        : _apiKey.text.trim();
    await state.settings.writeLlmSettings(settings, apiKey: key);
    await state.reload();
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('AI 配置已保存')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 配置'),
        actions: [
          TextButton(onPressed: _busy ? null : _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('仅用于把选中的证据整理成产物。API Key 只保存在本机隔离存储，页面不回显。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.secondary)),
          const SizedBox(height: 16),
          TextField(
              controller: _provider,
              decoration: const InputDecoration(
                  labelText: '服务商名称', hintText: '例如：OpenAI / DeepSeek / 自建')),
          const SizedBox(height: 12),
          TextField(
              controller: _baseUrl,
              decoration: const InputDecoration(
                  labelText: 'OpenAI 兼容 Base URL',
                  hintText: 'https://api.example.com/v1')),
          const SizedBox(height: 12),
          TextField(
              controller: _model,
              decoration: const InputDecoration(
                  labelText: '模型名', hintText: '例如：gpt-4o-mini')),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: _apiKeyVisible,
            builder: (context, visible, _) => TextField(
              controller: _apiKey,
              obscureText: !visible,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: '留空则保留已保存的 Key',
                suffixIcon: IconButton(
                  icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => _apiKeyVisible.value = !visible,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('出站边界',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('· 仅当你在「工作室」开启 AI 并选择证据后，才会发起真实调用。',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text('· 每次调用前都会展示出站披露，确认后才发送。',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text('· 只发送选中的最小字段，绝不上传整个记录池。',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}