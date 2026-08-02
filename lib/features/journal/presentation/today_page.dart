import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/cosmic_scaffold.dart';
import '../application/journal_controller.dart';
import '../domain/entry.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  final _task = TextEditingController();
  final _context = TextEditingController();
  final _action = TextEditingController();
  final _result = TextEditingController();
  final _blocker = TextEditingController();

  @override
  void dispose() {
    _task.dispose();
    _context.dispose();
    _action.dispose();
    _result.dispose();
    _blocker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(journalControllerProvider).value ?? [];
    final textTheme = Theme.of(context).textTheme;

    return CosmicScaffold(
      child: ListView(
        children: [
          Text('Daily Asking', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '每天记录一件真做过的小事，让 AI 只基于事实追问、整理和改写。',
            style: textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今天发生了什么？', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _Field(controller: _task, label: '01 具体做了什么', hint: '例如：整理竞品价格页截图'),
                _Field(controller: _context, label: '02 这件事为什么要做', hint: '它在项目里解决什么问题？'),
                _Field(controller: _action, label: '03 你怎么做的', hint: '流程、工具、判断标准、协作对象'),
                _Field(controller: _result, label: '04 结果或变化', hint: '有数字写数字，没有就写交付物'),
                _Field(controller: _blocker, label: '05 卡点/复盘', hint: '哪里难？如果重做会改什么？'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.add),
                  label: const Text('存入记录池'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日状态', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Metric(label: '累计记录', value: '${entries.length}'),
                    const SizedBox(width: 12),
                    _Metric(label: '可生成产物', value: entries.isEmpty ? '0' : '3'),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: entries.isEmpty ? null : () => context.go('/artifacts'),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('生成简历/周报/面试卡'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final task = _task.text.trim();
    if (task.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先写一句今天做了什么')));
      return;
    }

    final entry = Entry.create(
      task: task,
      context: _context.text.trim(),
      action: _action.text.trim(),
      result: _result.text.trim(),
      blocker: _blocker.text.trim(),
    );
    await ref.read(journalControllerProvider.notifier).addEntry(entry);
    _task.clear();
    _context.clear();
    _action.clear();
    _result.clear();
    _blocker.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已存入本地记录池')));
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, required this.hint});

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.55),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(label),
          ],
        ),
      ),
    );
  }
}
