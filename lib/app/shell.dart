/// 应用壳：底部导航 + 四个主页面。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../artifacts/studio_page.dart';
import '../evidence/evidence_page.dart';
import '../journal/today_page.dart';
import '../settings/settings_page.dart';
import '../settings/settings_repository.dart';
import '../updater/update_info.dart';
import 'app_state.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  static const _titles = ['今日', '记录', '工作室', '设置'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 启动后延迟自动检查：失败静默，强制更新时弹不可关闭框。
    Future.delayed(const Duration(seconds: 4), _autoCheckUpdate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 隔夜/跨零点后回到前台：刷新「今日」日期与列表，避免显示过期日期。
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().refreshToday();
    }
  }

  Future<void> _autoCheckUpdate() async {
    final state = context.read<AppState>();
    if (!state.updateService.isConfigured) return;
    final decision = await state.updateService.check();
    if (!mounted) return;
    switch (decision) {
      case UpdateAvailable(:final info):
        if (info.mandatory) {
          await _showMandatoryUpdate(info);
        } else if (await state.updateService.isAutoUpdateEnabled()) {
          final ok = await state.updateService.downloadAndInstall(info);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok ? '发现新版本 ${info.versionName}，已开始自动下载' : '更新下载失败，请重试',
              ),
            ),
          );
        }
      default:
        break; // NoUpdate / 失败：启动检查静默。
    }
  }

  /// 强制更新：不可关闭，返回键/外部点击均无效。
  Future<void> _showMandatoryUpdate(UpdateInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('需要更新到 ${info.versionName}'),
          content: SingleChildScrollView(
            child: Text(
              info.changelog.isNotEmpty ? info.changelog : '当前版本需要更新后才能继续使用。',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                await context.read<AppState>().updateService.downloadAndInstall(
                  info,
                );
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTheme() async {
    final state = context.read<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    await state.setTheme(
      dark ? ThemeModePreference.light : ThemeModePreference.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).colorScheme;
    final labelColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE6E3D8)
        : const Color(0xFF1F2A24);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: dark ? '切换亮色' : '切换深色',
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          TodayPage(),
          EvidencePage(),
          StudioPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          // 切回「今日」时顺带刷新（进程长期存活时日期可能已跨天）。
          if (i == 0) context.read<AppState>().refreshToday();
          setState(() => _index = i);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined, color: labelColor),
            selectedIcon: Icon(Icons.wb_sunny, color: style.primary),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined, color: labelColor),
            selectedIcon: Icon(Icons.hub, color: style.primary),
            label: '记录',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_mosaic_outlined, color: labelColor),
            selectedIcon: Icon(Icons.auto_awesome_mosaic, color: style.primary),
            label: '工作室',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined, color: labelColor),
            selectedIcon: Icon(Icons.tune, color: style.primary),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
