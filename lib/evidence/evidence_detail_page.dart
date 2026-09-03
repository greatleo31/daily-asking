/// 证据详情：查看、编辑、删除一条记录，并查看/回答其追问。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/export/markdown_exporter.dart';
import '../../core/models.dart';
import '../../core/utils.dart';
import 'question_card.dart';

class EvidenceDetailPage extends StatefulWidget {
  const EvidenceDetailPage({super.key, required this.entryId});
  final String entryId;

  @override
  State<EvidenceDetailPage> createState() => _EvidenceDetailPageState();
}

class _EvidenceDetailPageState extends State<EvidenceDetailPage> {
  late Future<Entry?> _future;
  List<EvidenceQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Entry?> _load() async {
    final state = context.read<AppState>();
    final e = await state.findEntry(widget.entryId);
    _questions = await state.questionsFor(widget.entryId);
    return e;
  }

  Future<void> _ask(BuildContext context, EvidenceQuestion q) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => QuestionCard(question: q),
    );
    if (mounted) setState(() => _load());
  }

  Future<void> _edit(BuildContext context, Entry e) async {
    // 捕获 messenger，避免在 await 之后使用 BuildContext（跨 async gap）。
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.of(context).push<Entry>(
      MaterialPageRoute(builder: (_) => EntryEditPage(entry: e)),
    );
    if (result != null && mounted) {
      try {
        await this.context.read<AppState>().updateEntry(result);
      } on SaveRollbackIncomplete {
        // 写入失败且回滚未完成：状态不确定，不得提示可重试。
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('保存状态不确定，请先刷新确认，暂不要重复提交')),
          );
        }
      } on SaveSucceededButRefreshFailed {
        // 更新已落盘但刷新失败：提示真实状态，下次进入时恢复。
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('已保存，但界面刷新失败，请稍后刷新查看')),
          );
        }
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('保存失败，请稍后重试')),
          );
        }
      }
      if (mounted) setState(() => _load());
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后其追问与回答也会一并移除，且无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await this.context.read<AppState>().deleteEntry(widget.entryId);
      if (mounted) Navigator.of(this.context).pop();
    }
  }

  Future<void> _export(BuildContext context, Entry e) async {
    final state = context.read<AppState>();
    final answers = <String, List<EvidenceAnswer>>{};
    for (final q in _questions) {
      answers[q.id] = await state.answersFor(q.id);
    }
    final md = entryToMarkdown(e, _questions, answers);
    final ok = await MarkdownShare.share(
      fileName: singleFileName(DateTime.now()),
      content: md,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(content: Text(ok ? '已导出并唤起分享' : '导出失败，请重试')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('记录详情')),
      body: FutureBuilder<Entry?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final e = snap.data;
          if (e == null) {
            return const Center(child: Text('记录不存在'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(e.date.cnLabel,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.secondary)),
                  ),
                  _Tag(count: e.completenessPercent(), label: '完整度'),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _export(context, e),
                    icon: const Icon(Icons.ios_share),
                    tooltip: '导出 Markdown',
                  ),
                  IconButton(
                    onPressed: () => _edit(context, e),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: '编辑',
                  ),
                  IconButton(
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    tooltip: '删除',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(e.task,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _Section('背景', e.context),
              _Section('具体行动', e.action),
              _Section('结果 / 验证', e.result),
              _Section('难点 / 取舍', e.blocker),
              if (e.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('标签',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.secondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: e.tags.map((t) => Chip(label: Text('#$t'))).toList()),
              ],
              const SizedBox(height: 24),
              Text('待补充',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_questions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('这条记录暂无追问。',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.secondary)),
                )
              else
                ..._questions.map((q) => _QuestionTile(
                      q: q,
                      onAnswer: () => _ask(context, q),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.content);
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = content.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.secondary)),
          const SizedBox(height: 4),
          Text(
            empty ? '（未记录）' : content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: empty
                  ? theme.colorScheme.outline
                  : theme.colorScheme.onSurface,
              fontStyle: empty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = count >= 80
        ? theme.colorScheme.primary
        : count >= 40
            ? const Color(0xFFC98A2D)
            : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text('$label $count%',
          style: theme.textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.q, required this.onAnswer});
  final EvidenceQuestion q;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = q.status == QuestionStatus.answered;
    final skipped = q.status == QuestionStatus.skip;

    final String statusText;
    final Color? statusFg;
    final Color? statusBg;
    final Color? statusBorder;
    if (done) {
      statusText = '已答';
      statusFg = theme.colorScheme.onPrimary;
      statusBg = theme.colorScheme.primary;
      statusBorder = null;
    } else if (skipped) {
      statusText = '已跳过';
      statusFg = theme.colorScheme.secondary;
      statusBg = null;
      statusBorder = theme.colorScheme.outline;
    } else {
      statusText = '待补充';
      statusFg = theme.colorScheme.onError;
      statusBg = theme.colorScheme.error;
      statusBorder = null;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(q.kind.label),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusBg,
            border: statusBorder == null
                ? null
                : Border.all(color: statusBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            statusText,
            style: theme.textTheme.labelMedium?.copyWith(
              color: statusFg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: done || skipped ? null : onAnswer,
      ),
    );
  }
}

/// 编辑页。
class EntryEditPage extends StatefulWidget {
  const EntryEditPage({super.key, required this.entry});
  final Entry entry;

  @override
  State<EntryEditPage> createState() => _EntryEditPageState();
}

class _EntryEditPageState extends State<EntryEditPage> {
  late final TextEditingController _task;
  late final TextEditingController _context;
  late final TextEditingController _action;
  late final TextEditingController _result;
  late final TextEditingController _blocker;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _task = TextEditingController(text: e.task);
    _context = TextEditingController(text: e.context);
    _action = TextEditingController(text: e.action);
    _result = TextEditingController(text: e.result);
    _blocker = TextEditingController(text: e.blocker);
    _tags = TextEditingController(text: e.tags.join('，'));
  }

  @override
  void dispose() {
    _task.dispose();
    _context.dispose();
    _action.dispose();
    _result.dispose();
    _blocker.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _save() {
    final e = widget.entry;
    e.task = _task.text.trim();
    e.context = _context.text.trim();
    e.action = _action.text.trim();
    e.result = _result.text.trim();
    e.blocker = _blocker.text.trim();
    e.tags = _tags.text
        .split(RegExp(r'[,，\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.of(context).pop(e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑记录'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
              controller: _task,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '事实 *')),
          const SizedBox(height: 12),
          TextField(
              controller: _context,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '背景')),
          const SizedBox(height: 12),
          TextField(
              controller: _action,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '具体行动')),
          const SizedBox(height: 12),
          TextField(
              controller: _result,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '结果 / 验证')),
          const SizedBox(height: 12),
          TextField(
              controller: _blocker,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '难点 / 取舍')),
          const SizedBox(height: 12),
          TextField(
              controller: _tags,
              decoration: const InputDecoration(
                  labelText: '标签（用逗号分隔，可留空）')),
          const SizedBox(height: 24),
          Text('完整度 ${widget.entry.completenessPercent()}%',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
