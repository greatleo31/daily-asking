import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellPage extends StatelessWidget {
  const ShellPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = switch (location) {
      '/timeline' => 1,
      '/artifacts' => 2,
      '/settings' => 3,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          final path = switch (value) {
            1 => '/timeline',
            2 => '/artifacts',
            3 => '/settings',
            _ => '/',
          };
          context.go(path);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: '今日'),
          NavigationDestination(icon: Icon(Icons.timeline), label: '记录池'),
          NavigationDestination(icon: Icon(Icons.style), label: '产物'),
          NavigationDestination(icon: Icon(Icons.tune), label: '设置'),
        ],
      ),
    );
  }
}
