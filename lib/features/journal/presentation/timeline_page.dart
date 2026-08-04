import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/cosmic_scaffold.dart';
import '../application/journal_controller.dart';
import '../application/journal_exporter.dart';
import '../application/journal_filter.dart';
import '../domain/entry.dart';

class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  final _query = TextEditingController();
  final _exporter = const JournalExporter();
  final _selectedIds = <String>{};
  DateTimeRange? _range;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesState = ref.watch(journalControllerProvider);
    return CosmicScaffold(
      child: entriesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(error: error, onRetry: () => ref.read(journalControllerProvider.notifier).load()),
        data: (entries) => _buildEntries(context, entries),
      ),
    );
  }

  Widget _buildEntries(BuildContext context, List<Entry> entries) {
    final filter = JournalFilter(query: _query.text, startDate: _range?.start, endDate: _range?.end);
    final filtered = filterEntries(entries, filter);
    final selected = filtered.where((entry) => _selectedIds.contains(entry.id)).toList();
    final exportSource = selected.isEmpty ? filtered : selected;

    return ListView.separated(
      itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Header(
            query: _query,
            range: _range,
            totalCount: entries.length,
            filteredCount: filtered.length,
            selectedCount: selected.length,
            onChanged: () => setState(() {}),
            onPickRange: _pickRange,
            onClearRange: () => setState(() => _range = null),
            onExportMarkdown: exportSource.isEmpty ? null : () => _showExport(exportSource, markdown: true),
            onExportJson: exportSource.isEmpty ? null : () => _showExport(exportSource, markdown: false),
          );
        }

        if (filtered.isEmpty) {
          return const AppCard(child: Text('没有匹配的记录。可以清空搜索或调整日期范围，原始记录不会丢失。'));
        }

        final entry = filtered[index - 1];
        return _EntryCard(
          entry: entry,
          selected: _selectedIds.contains(entry.id),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedIds.add(entry.id);
              } else {
                _selectedIds.remove(entry.id);
              }
            });
          },
          onEdit: () => _editEntry(entry),
          onDelete: () => _confirmDelete(entry),
        );
      },
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  Future<void> _editEntry(Entry entry) async {
    final updated = await showDialog<Entry>(
      context: context,
      builder: (context) => _EntryEditorDialog(entry: entry),
    );
    if (updated == null || !mounted) return;
    try {
      await ref.read(journalControllerProvider.notifier).updateEntry(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('记录已更新')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败：$error')));
      }
    }
  }

  Future<void> _confirmDelete(Entry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录？'),
        content: Text('将删除“${entry.task}”。删除后不会再作为 AI 产物来源。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(journalControllerProvider.notifier).deleteEntry(entry.id);
      setState(() => _selectedIds.remove(entry.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('记录已删除')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败：$error')));
      }
    }
  }

  Future<void> _showExport(List<Entry> entries, {required bool markdown}) async {
    try {
      final content = markdown ? _exporter.toMarkdown(entries) : _exporter.toJson(entries);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(markdown ? 'Markdown 导出' : 'JSON 导出'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(content)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导出内容已复制')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('复制'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败：$error')));
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.query,
    required this.range,
    required this.totalCount,
    required this.filteredCount,
    required this.selectedCount,
    required this.onChanged,
    required this.onPickRange,
    required this.onClearRange,
    required this.onExportMarkdown,
    required this.onExportJson,
  });

  final TextEditingController query;
  final DateTimeRange? range;
  final int totalCount;
  final int filteredCount;
  final int selectedCount;
  final VoidCallback onChanged;
  final VoidCallback onPickRange;
  final VoidCallback onClearRange;
  final VoidCallback? onExportMarkdown;
  final VoidCallback? onExportJson;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final formatter = DateFormat('MM/dd');
    final rangeLabel = range == null ? '选择日期范围' : '${formatter.format(range!.start)} - ${formatter.format(range!.end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('记录池', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: query,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: '搜索记录', hintText: '任务、行动、结果、标签'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(onPressed: onPickRange, icon: const Icon(Icons.date_range), label: Text(rangeLabel)),
                  if (range != null) TextButton(onPressed: onClearRange, child: const Text('清空日期')),
                  OutlinedButton.icon(onPressed: onExportMarkdown, icon: const Icon(Icons.description), label: const Text('导出 Markdown')),
                  OutlinedButton.icon(onPressed: onExportJson, icon: const Icon(Icons.data_object), label: const Text('导出 JSON')),
                ],
              ),
              const SizedBox(height: 10),
              Text('共 $totalCount 条，当前显示 $filteredCount 条；已选择 $selectedCount 条。未选择时导出当前筛选结果。'),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.selected,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final Entry entry;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MM月dd日 HH:mm');
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: selected, onChanged: (value) => onSelected(value ?? false)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatter.format(entry.date), style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(entry.task, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (entry.context.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('背景：${entry.context}'),
                ],
                if (entry.action.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('行动：${entry.action}'),
                ],
                if (entry.result.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('结果：${entry.result}'),
                ],
                if (entry.blocker.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('卡点：${entry.blocker}'),
                ],
                if (entry.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [for (final tag in entry.tags) Chip(label: Text(tag))]),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit), label: const Text('编辑')),
                    OutlinedButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline), label: const Text('删除')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryEditorDialog extends StatefulWidget {
  const _EntryEditorDialog({required this.entry});

  final Entry entry;

  @override
  State<_EntryEditorDialog> createState() => _EntryEditorDialogState();
}

class _EntryEditorDialogState extends State<_EntryEditorDialog> {
  late final TextEditingController _task;
  late final TextEditingController _context;
  late final TextEditingController _action;
  late final TextEditingController _result;
  late final TextEditingController _blocker;
  late final TextEditingController _tags;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _task = TextEditingController(text: widget.entry.task);
    _context = TextEditingController(text: widget.entry.context);
    _action = TextEditingController(text: widget.entry.action);
    _result = TextEditingController(text: widget.entry.result);
    _blocker = TextEditingController(text: widget.entry.blocker);
    _tags = TextEditingController(text: widget.entry.tags.join(', '));
    _date = widget.entry.date;
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑记录'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _task, decoration: const InputDecoration(labelText: '具体做了什么')),
            const SizedBox(height: 10),
            TextField(controller: _context, decoration: const InputDecoration(labelText: '为什么要做')),
            const SizedBox(height: 10),
            TextField(controller: _action, decoration: const InputDecoration(labelText: '怎么做的')),
            const SizedBox(height: 10),
            TextField(controller: _result, decoration: const InputDecoration(labelText: '结果或变化')),
            const SizedBox(height: 10),
            TextField(controller: _blocker, decoration: const InputDecoration(labelText: '卡点/复盘')),
            const SizedBox(height: 10),
            TextField(controller: _tags, decoration: const InputDecoration(labelText: '标签，用逗号分隔')),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event),
                label: Text(DateFormat('yyyy-MM-dd HH:mm').format(_date)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 1),
      initialDate: _date,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time?.hour ?? _date.hour, time?.minute ?? _date.minute);
    });
  }

  void _save() {
    final task = _task.text.trim();
    if (task.isEmpty) return;
    final tags = _tags.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
    Navigator.of(context).pop(
      widget.entry.copyWith(
        date: _date,
        task: task,
        context: _context.text.trim(),
        action: _action.text.trim(),
        result: _result.text.trim(),
        blocker: _blocker.text.trim(),
        tags: tags,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('读取记录失败', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('$error'),
            const SizedBox(height: 12),
            const Text('为避免覆盖本地数据，请先确认数据状态后再新增或导出。'),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('重试读取')),
          ],
        ),
      ),
    );
  }
}
