/// 设置：供应商 AI 配置入口 + 关于入口。分组可折叠，右上角有全局主题切换。
///
/// API Key 不回显、不写普通数据库；提供清除配置按钮。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/version.dart';
import '../artifacts/generation_waiting_overlay.dart';
import '../core/export/markdown_exporter.dart';
import '../core/transfer/data_transfer_service.dart';
import '../core/transfer/file_pick_service.dart';
import '../core/transfer/transfer_partition.dart';
import 'import_preview_page.dart';
import 'import_result_page.dart';
import 'about_page.dart';
import 'settings_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.filePicker = const FilePickService(),
    this.dataTransferService,
    this.onViewImportedRecords,
  });

  final FilePickService filePicker;
  final DataTransferService? dataTransferService;
  final VoidCallback? onViewImportedRecords;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoUpdate = false;
  bool _transferBusy = false;
  DateTime? _latestBackupAt;
  late final DataTransferService _transfer;

  @override
  void initState() {
    super.initState();
    _transfer = widget.dataTransferService ?? DataTransferService();
    _loadAutoUpdate();
    _loadLatestBackup();
  }

  Future<void> _loadAutoUpdate() async {
    final enabled = await context
        .read<AppState>()
        .updateService
        .isAutoUpdateEnabled();
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
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
              leading: Icon(
                Icons.spa_outlined,
                color: theme.colorScheme.secondary,
              ),
              title: const Text('伙伴'),
              subtitle: Text(
                companion.growthDays == 0
                    ? '尚未开始成长'
                    : '${companion.name ?? '晨昏伙伴'} · 累计 ${companion.growthDays} 天',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              initiallyExpanded: true,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.restart_alt,
                    color: Color(0xFFB8452F),
                  ),
                  title: const Text('重置伙伴成长'),
                  subtitle: Text(
                    '清空名称、累计成长日与节点状态；不删除任何记录',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
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
              leading: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.secondary,
              ),
              title: const Text('供应商配置'),
              subtitle: Text(
                aiReady ? '已配置 · ${llmSettings.provider}' : '未配置',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
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
                            : theme.colorScheme.outline,
                      ),
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'API Key：已保存（不显示）',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
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
          // 数据组：结构化导出与导入；自动快照只读展示。
          Card(
            child: ExpansionTile(
              leading: Icon(
                Icons.folder_outlined,
                color: theme.colorScheme.secondary,
              ),
              title: const Text('数据'),
              initiallyExpanded: true,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.ios_share),
                  title: const Text('导出数据（可再导入）'),
                  onTap: _transferBusy ? null : _exportData,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.file_open_outlined),
                  title: const Text('导入记录'),
                  subtitle: const Text('选择 JSON 或 Markdown 文件，可多选'),
                  onTap: _transferBusy ? null : _importRecords,
                ),
                Text(
                  '上次自动备份：${_latestBackupAt == null ? '暂无' : _formatBackupTime(_latestBackupAt!)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 关于组（可折叠）。
          Card(
            child: ExpansionTile(
              leading: Icon(
                Icons.info_outline,
                color: theme.colorScheme.secondary,
              ),
              title: const Text('关于'),
              subtitle: Text('版本 v$kAppVersionName · 留痕'),
              initiallyExpanded: true,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('关于留痕'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBackupTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _loadLatestBackup() async {
    try {
      final latest = await _transfer.latestBackupAt();
      if (mounted) setState(() => _latestBackupAt = latest);
    } catch (_) {
      // 快照查询失败不泄露路径或异常内容，也不阻塞设置页。
    }
  }

  void _transferMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<T> _waitForImport<T>(Future<T> Function() operation) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final state = context.read<AppState>();
    final route = PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => GenerationWaitingOverlay(
        title: '正在导入…',
        hint: '请稍候，导入完成后会自动继续',
        dismissible: false,
        stage: state.companionStage,
        name: state.companion.name,
      ),
    );
    navigator.push(route);
    try {
      // 先绘制等待状态，再开始读取和规划。
      await WidgetsBinding.instance.endOfFrame;
      return await operation();
    } finally {
      // 只移除自己创建的蒙层，不误关其它路由。
      if (route.isActive) navigator.removeRoute(route);
    }
  }

  Future<void> _importRecords() async {
    if (_transferBusy) return;
    final state = context.read<AppState>();
    setState(() => _transferBusy = true);
    try {
      final plan = await _waitForImport(() async {
        final files = await widget.filePicker.pickFiles();
        if (files == null || files.isEmpty) return null;
        return _transfer.prepare(files, state);
      });
      if (!mounted || plan == null) return;
      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ImportPreviewPage(plan: plan)),
      );
      if (!mounted || confirmed != true) return;
      final result = await _waitForImport(() => _transfer.execute(plan, state));
      if (!mounted) return;
      await _loadLatestBackup();
      if (!mounted) return;
      final viewRecords = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ImportResultPage(result: result)),
      );
      if (mounted && viewRecords == true) widget.onViewImportedRecords?.call();
    } catch (_) {
      _transferMessage('导入未完成，请重试');
    } finally {
      if (mounted) setState(() => _transferBusy = false);
    }
  }

  Future<void> _exportData() async {
    if (_transferBusy) return;
    final state = context.read<AppState>();
    setState(() => _transferBusy = true);
    try {
      final files = await buildAllJsonFiles(state);
      // 条数取自实际导出的快照，不依赖页面可能过期的内存列表。
      final count = files.fold<int>(0, (total, file) {
        final data = jsonDecode(file.content) as Map<String, dynamic>;
        return total + (data['entries'] as List).length;
      });
      final ok = await MarkdownShare.shareFiles(files);
      final partsHint = files.length > 1
          ? '。共 ${files.length} 个文件，完整迁移请全部导入'
          : '';
      _transferMessage(ok ? '文件含你的全部记录（$count 条），请谨慎分享$partsHint' : '导出失败，请重试');
    } on TransferPartitionException catch (error) {
      _transferMessage(error.message);
    } catch (_) {
      _transferMessage('导出失败，请重试');
    } finally {
      if (mounted) setState(() => _transferBusy = false);
    }
  }

  Future<void> _configureAi(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AiConfigPage()));
  }

  Future<void> _clearAi() async {
    final state = context.read<AppState>();
    await state.clearLlmSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除 AI 配置')));
  }

  /// 重置伙伴成长：要求明确二次确认后才执行；只清伙伴资料，证据不受影响。
  Future<void> _confirmResetCompanion() async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置伙伴成长？'),
        content: const Text('将清空伙伴名称、累计成长日与节点状态。\n\n已有记录不会被删除，且不受任何影响。'),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('伙伴已重置，记录保持不变')));
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
    final key = _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim();
    await state.saveLlmSettings(settings, apiKey: key);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI 配置已保存')));
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
          Text(
            '仅用于把选中的记录整理成简历 / 周报 / 面试卡。Key 只保存在本机，页面不回显。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _provider,
            decoration: const InputDecoration(
              labelText: '服务商名称',
              hintText: '例如：OpenAI / DeepSeek / 自建',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'OpenAI 兼容 Base URL',
              hintText: 'https://api.example.com/v1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: '模型名',
              hintText: '例如：gpt-4o-mini',
            ),
          ),
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
          Text(
            '出站边界',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '· 仅当你在「工作室」开启 AI 并选择记录后，才会发起真实调用。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text('· 每次调用前都会展示出站披露，确认后才发送。', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text('· 只发送选中的最小字段，绝不上传整个记录池。', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
