/// 证据库：本地记录列表 + 搜索/筛选 + 证据图谱。
///
/// 图谱为非惩罚性：不做断签清零，不制造焦虑。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/export/markdown_exporter.dart';
import '../../core/models.dart';
import '../../core/utils.dart';
import 'evidence_detail_page.dart';
import 'evidence_graph.dart';

enum _Filter { all, recent7, recent30 }

class EvidencePage extends StatefulWidget {
  const EvidencePage({super.key});

  @override
  State<EvidencePage> createState() => _EvidencePageState();
}

class _EvidencePageState extends State<EvidencePage> {
  final _search = TextEditingController();
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Entry> _apply(List<Entry> all) {
    var list = List.of(all);
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final text =
            '${e.task}${e.context}${e.action}${e.result}${e.blocker}${e.tags.join()}'
                .toLowerCase();
        return text.contains(q);
      }).toList();
    }
    final now = DateTime.now();
    switch (_filter) {
      case _Filter.recent7:
        list = list
            .where((e) => now.difference(e.date).inDays <= 7)
            .toList();
      case _Filter.recent30:
        list = list
            .where((e) => now.difference(e.date).inDays <= 30)
            .toList();
      case _Filter.all:
        break;
    }
    return list;
  }

  Future<void> _exportAll(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.allEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('还没有可导出的证据')));
      return;
    }
    final md = await buildAllMarkdown(state);
    final ok = await MarkdownShare.share(
      fileName: allFileName(DateTime.now()),
      content: md,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(content: Text(ok ? '已导出并唤起分享' : '导出失败，请重试')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final list = _apply(state.allEntries);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('共 ${state.allEntries.length} 条',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.secondary)),
              ),
              TextButton.icon(
                onPressed: () => _exportAll(context),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('导出全部'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 图谱。
          EvidenceGraph(metrics: state.metrics),
          const SizedBox(height: 20),
          // 搜索 + 筛选。
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: '搜索关键词…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _FilterChip(
                label: '全部',
                selected: _filter == _Filter.all,
                onTap: () => setState(() => _filter = _Filter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '近 7 天',
                selected: _filter == _Filter.recent7,
                onTap: () => setState(() => _filter = _Filter.recent7),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: '近 30 天',
                selected: _filter == _Filter.recent30,
                onTap: () => setState(() => _filter = _Filter.recent30),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            _EmptyState(
                hasEntries: state.allEntries.isNotEmpty,
                query: _query)
          else
            ...list.map((e) => _EntryCard(entry: e)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            )),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => EvidenceDetailPage(entryId: entry.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(entry.date.cnLabel,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.secondary)),
                  ),
                  _CompletenessBadge(percent: entry.completenessPercent()),
                ],
              ),
              const SizedBox(height: 8),
              Text(entry.task,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: entry.tags
                      .map((t) => Chip(
                            label: Text('#$t'),
                            labelStyle: theme.textTheme.labelSmall,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletenessBadge extends StatelessWidget {
  const _CompletenessBadge({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = percent >= 80
        ? theme.colorScheme.primary
        : percent >= 40
            ? const Color(0xFFC98A2D)
            : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('完整度 $percent%',
          style: theme.textTheme.labelSmall?.copyWith(color: color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasEntries, required this.query});
  final bool hasEntries;
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(query.isEmpty ? Icons.hub_outlined : Icons.search_off,
              color: theme.colorScheme.secondary, size: 32),
          const SizedBox(height: 8),
          Text(query.isEmpty ? '还没有证据记录' : '没有匹配"$query"的记录',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            query.isEmpty
                ? '去「今日」记录第一件小事，证据图谱会从这里开始。'
                : '换个关键词试试。',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.secondary),
          ),
        ],
      ),
    );
  }
}