/// 关于页：版本、隐私边界、开源许可、更新入口。
library;

import 'package:flutter/material.dart';

/// 当前版本（与 pubspec.yaml version 保持一致）。
const appVersion = 'v1.0.0';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
                Icon(Icons.wb_twilight,
                    size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('晨昏证据图谱',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(appVersion,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.secondary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('隐私边界',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
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
          Text('开源许可',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.code),
              title: const Text('MIT License'),
              subtitle: const Text('本应用代码以 MIT 许可开源。'),
            ),
          ),
          const SizedBox(height: 16),
          Text('更新',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text('检查更新'),
              subtitle: const Text(appVersion),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('已是最新版本'))),
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
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
