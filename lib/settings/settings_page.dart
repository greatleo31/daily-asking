/// 设置：供应商 AI 配置入口 + 关于入口。分组可折叠，右上角有全局主题切换。
///
/// API Key 不回显、不写普通数据库；提供清除配置按钮。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/version.dart';
import 'about_page.dart';
import 'settings_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadAutoUpdate();
  }

  Future<void> _loadAutoUpdate() async {
    final enabled =
        await context.read<AppState>().updateService.isAutoUpdateEnabled();
    if (mounted) setState(() => _autoUpdate = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiReady = context.select((AppState s) => s.aiReady);
    final llmSettings = context.select((AppState s) => s.llmSettings);
    final companion = context.select((AppState s) => s.companion);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          // 通用组（可折叠）：自动更新开关。
          Card(
            child: ExpansionTile(
              leading: Icon(Icons.tune, color: theme.colorScheme.secondary),
              title: const Text('通用'),
              initiallyExpanded: true,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.system_update_alt),
                  title: const Text('自动更新'),
                  subtitle: Text(
                    _autoUpdate ? '发现新版本时自动下载并安装' : '发现新版本时仅提示',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  value: _autoUpdate,
                  onChanged: (v) async {
                    setState(() => _autoUpdate = v);
                    await context
                        .read<AppState>()
                        .updateService
                        .setAutoUpdateEnabled(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 伙伴组（可折叠）：伙伴资料概览与独立重置。
          Card(
            child: ExpansionTile(
              leading: Icon(Icons.spa_outlined,
                  color: theme.colorScheme.secondary),
              title: const Text('伙伴'),
              subtitle: Text(
                companion.growthDays == 0
                    ? '尚未开始成长'
                    : '${companion.name ?? '晨昏伙伴'} · 累计 ${companion.growthDays} 天',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.secondary),
              ),
              initiallyExpanded: true,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.restart_alt,
                      color: Color(0xFFB8452F)),
                  title: const Text('重置伙伴成长'),
                  subtitle: Text(
                    '清空名称、累计成长日与节点状态；不删除任何证据记录',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _confirmResetCompanion,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 供应商配置组（可折叠）。
          Card(
            child: ExpansionTile(
              leading: Icon(Icons.auto_awesome,
                  color: theme.colorScheme.secondary),
              title: const Text('供应商配置'),
              subtitle: Text(
                aiReady
                    ? '已配置 · ${llmSettings.provider}'
                    : '未配置',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.secondary),
              ),
              initiallyExpanded: true,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: aiReady
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      aiReady ? '已配置' : '未配置',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: aiReady
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _configureAi(context),
                      child: Text(aiReady ? '修改' : '配置'),
                    ),
                  ],
                ),
                if (aiReady) ...[
                  const SizedBox(height: 8),
                  Text(
                    '服务商：${llmSettings.provider} · 模型：${llmSettings.model}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 4),
                  Text('API Key：已保存（不显示）',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.secondary)),
                  const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          // 关于组（可折叠）。
          Card(
            child: ExpansionTile(
              leading:
                  Icon(Icons.info_outline, color: theme.colorScheme.secondary),
              title: const Text('关于'),
              subtitle: Text('版本 v$kAppVersionName · 晨昏证据图谱'),
              initiallyExpanded: true,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('关于晨昏证据图谱'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutPage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _configureAi(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiConfigPage()),
    );
  }

  Future<void> _clearAi() async {
    final state = context.read<AppState>();
    await state.clearLlmSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已清除 AI 配置')));
  }

  /// 重置伙伴成长：要求明确二次确认后才执行；只清伙伴资料，证据不受影响。
  Future<void> _confirmResetCompanion() async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置伙伴成长？'),
        content: const Text('将清空伙伴名称、累计成长日与节点状态。\n\n已有证据记录不会被删除，且不受任何影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB8452F),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await state.resetCompanion();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('伙伴已重置，证据记录保持不变')),
    );
  }
}

/// 供应商 AI 配置页。API Key 输入不回显（obscure），保存后仅存隔离存储。
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
    final s = await state.readLlmSettings();
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
    final key =
        _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim();
    await state.saveLlmSettings(settings, apiKey: key);
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
        title: const Text('供应商配置'),
        actions: [
          TextButton(onPressed: _busy ? null : _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('仅用于把选中的证据整理成简历 / 周报 / 面试卡。Key 只保存在本机，页面不回显。',
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
