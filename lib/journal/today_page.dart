/// 今日：快速记录一句话事实 → 保存 → 本地追问。
///
/// 不允许因未回答追问而阻止保存；追问可回答 / 稍后 / 跳过。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/models.dart';
import '../../core/utils.dart';
import '../evidence/question_card.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(BuildContext context) async {
    final state = context.read<AppState>();
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先写一句今天发生的真实小事吧')),
      );
      return;
    }
    _controller.clear();
    final q = await state.saveQuickToday(text);
    if (!mounted) return;
    if (q != null) {
      await _showQuestionDialog(this.context, q);
    } else {
      ScaffoldMessenger.of(this.context)
          .showSnackBar(const SnackBar(content: Text('已保存 ✓')));
    }
  }

  Future<void> _showQuestionDialog(BuildContext context, EvidenceQuestion q) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => QuestionCard(question: q),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('今日',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      DateTime.now().cnLabel,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.secondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '本地 · 无账号',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 快速记录输入区。
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今天发生了什么真实小事？',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('30 秒记一句事实，保存后我会追问一个最值得补充的点。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.secondary)),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  maxLines: 3,
                  minLines: 2,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: '例如：给新入职的同事做了 SQL 培训，帮他跑通了周报脚本',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _save(context),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存并沉淀'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _TodayOverview(state: state),
        ],
      ),
    );
  }
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = state.todayEntries;
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.wb_twilight, color: theme.colorScheme.secondary),
            const SizedBox(height: 8),
            Text('今天还没有沉淀证据',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('在上面记下第一件小事，你的证据图谱会从这里长出来。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.secondary)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('今日已沉淀',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              value: '${state.todayCount}',
              label: '条证据',
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  state.lastFeedbackLabel ?? '',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...list.take(5).map((e) => _TodayEntryTile(entry: e)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 96,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w800)),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _TodayEntryTile extends StatelessWidget {
  const _TodayEntryTile({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Text(
            '${entry.completenessPercent()}%',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        title: Text(entry.task,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '完整度 ${entry.completenessPercent()}%',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.secondary),
        ),
        trailing: Icon(Icons.chevron_right,
            color: theme.colorScheme.secondary),
        onTap: () {},
      ),
    );
  }
}