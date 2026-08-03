import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/cosmic_scaffold.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return CosmicScaffold(
      child: Center(
        child: AppCard(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('先说清楚隐私边界', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              const Text('Daily Asking 默认本地优先。没有配置 AI 时，记录、编辑、导出都只在本机完成。'),
              const SizedBox(height: 10),
              const Text('启用 AI 后，每次发送前都会确认；只发送当前生成任务必要的记录片段，不会默认上传整个记录池。'),
              const SizedBox(height: 10),
              const Text('你的 LLM API Key 只应进入系统安全存储，不写入数据库、日志或迁移包。'),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('我理解，开始记录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
