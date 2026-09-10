/// 关于页：版本、隐私边界、开源许可、更新入口。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/version.dart';
import '../updater/update_dialogs.dart';
import '../updater/update_info.dart';
import '../app/app_state.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool _checking = false;
  String _lastChecked = '从未检查';

  @override
  void initState() {
    super.initState();
    _refreshLastChecked();
  }

  /// 「上次检查」文本只在挂载时与每次检查后刷新，不在 build 里新建 Future——
  /// 否则每次 rebuild（切主题、切开关）都会先闪一下「从未检查」再跳回真实时间。
  Future<void> _refreshLastChecked() async {
    final dt = await context.read<AppState>().updateService.lastCheckedAt;
    if (!mounted) return;
    if (dt == null) {
      setState(() => _lastChecked = '从未检查');
      return;
    }
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    setState(() {
      _lastChecked =
          '上次检查 ${local.year}-${two(local.month)}-${two(local.day)} '
          '${two(local.hour)}:${two(local.minute)}';
    });
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    final state = context.read<AppState>();
    final decision = await state.updateService.check();
    if (!mounted) return;
    setState(() => _checking = false);
    await _refreshLastChecked();
    if (!mounted) return;
    switch (decision) {
      case NoUpdate():
        _toast('已是最新版本');
      case UpdateCheckFailed(:final reason):
        _toast(reason == '更新服务未配置' ? '更新服务未配置' : '检查更新失败，请稍后重试');
      case UpdateAvailable(:final info):
        if (info.isMandatoryFor(kAppVersionCode)) {
          await _showMandatoryUpdate(info);
        } else {
          await _showNormalUpdate(info);
        }
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _startDownload(UpdateInfo info) async {
    final state = context.read<AppState>();
    final ok = await state.updateService.downloadAndInstall(info);
    if (!mounted) return;
    _toast(ok ? '已开始下载，可在通知栏查看进度' : '更新下载失败，请重试');
  }

  /// 非强制更新：可关闭，点「立即更新」才下载。
  Future<void> _showNormalUpdate(UpdateInfo info) => showUpdateAvailableDialog(
        context,
        info,
        onUpdate: () => _startDownload(info),
      );

  /// 强制更新：不可关闭（返回键/外部点击均无效），仅「立即更新」，带防重复点击。
  Future<void> _showMandatoryUpdate(UpdateInfo info) => showMandatoryUpdateDialog(
        context,
        info,
        onUpdate: () => _startDownload(info),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.wb_twilight,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  '留痕',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v$kAppVersionName ($kAppVersionCode)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '隐私边界',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _privacyRow(theme, '所有记录默认保存在本机，不出设备。'),
                  _privacyRow(theme, '无账号、无登录、无订阅、无云同步、无遥测。'),
                  _privacyRow(theme, '真实 AI 调用只发送你选中的最小字段，且出站前确认。'),
                  _privacyRow(theme, '日志不记录 API Key、记录正文与提示词全文。'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '开源许可',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.code),
              title: const Text('MIT License'),
              subtitle: const Text('本应用代码以 MIT 许可开源。'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '更新',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.system_update_alt),
                  title: const Text('检查更新'),
                  subtitle: Text(_checking ? '检查中…' : _lastChecked),
                  trailing: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _checkUpdate,
                ),
              ],
            ),
          ),
        ],
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
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
