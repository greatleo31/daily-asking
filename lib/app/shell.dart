/// 应用壳：底部导航 + 四个主页面。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../artifacts/studio_page.dart';
import '../evidence/evidence_page.dart';
import '../journal/today_page.dart';
import '../settings/settings_page.dart';
import '../settings/settings_repository.dart';
import 'app_state.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titles = ['今日', '证据', '工作室', '设置'];

  Future<void> _toggleTheme() async {
    final state = context.read<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    await state.setTheme(
        dark ? ThemeModePreference.light : ThemeModePreference.dark);
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
                dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
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
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined, color: labelColor),
            selectedIcon: Icon(Icons.wb_sunny, color: style.primary),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined, color: labelColor),
            selectedIcon: Icon(Icons.hub, color: style.primary),
            label: '证据',
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

/// 全局壳入口：等待 AppState 就绪后渲染。
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.loaded) {
      // 首次进入：空态引导（不影响快速记录）。
      return const AppShell();
    }
    return const AppShell();
  }
}