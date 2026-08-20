/// 产物查看/编辑页：把 AI 输出解析为「可验证的决策结果视图」。
///
/// 设计定位（Agent / LLM UI）：
/// - 结论优先：首屏先看到综合评价与核心结论；
/// - Evidence First：结论旁展示支持/缺失证据，风险独立呈现；
/// - 不虚构数据：评级、置信度、证据来源等字段当前并不存在，
///   一律不伪造；「待补充 / 偏浅」数量只统计内容中真实出现的标记；
/// - 原文始终可查：原始 Markdown 折叠在底部供核验；
/// - 免责声明移到底部，不抢占首屏。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/export/markdown_exporter.dart';
import '../../core/models.dart';
import '../../core/utils.dart';
import 'artifact_content_parser.dart';
import 'studio_page.dart';

enum _ArtifactAction { edit, copy, export, reanalyze, delete }

class ArtifactViewPage extends StatefulWidget {
  const ArtifactViewPage({super.key, required this.artifactId});
  final String artifactId;

  @override
  State<ArtifactViewPage> createState() => _ArtifactViewPageState();
}

class _ArtifactViewPageState extends State<ArtifactViewPage> {
  late Future<Artifact?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Artifact?> _load() =>
      context.read<AppState>().artifactRepo.find(widget.artifactId);

  Future<void> _saveEdited(Artifact a) async {
    await context.read<AppState>().updateArtifact(a);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }

  void _edit(BuildContext context, Artifact a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ArtifactEditor(
        artifact: a,
        onSave: (content) => _saveEdited(a..content = content),
      ),
    );
  }

  Future<void> _copy(Artifact a) async {
    await Clipboard.setData(ClipboardData(text: a.content));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制产物内容')));
    }
  }

  Future<void> _export(Artifact a) async {
    final ok = await MarkdownShare.share(
      fileName: artifactFileName(a, DateTime.now()),
      content: artifactToMarkdown(a),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '已导出并唤起分享' : '导出失败，请重试')));
    }
  }

  /// 重新分析：带着生成该产物的证据回到工作室，按需调整后重新生成。
  Future<void> _reanalyze(Artifact a) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudioPage(
          initialEntryIds: a.sourceEntryIds,
          showAppBar: true,
        ),
      ),
    );
  }

  Future<void> _delete(Artifact a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这份产物？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    await context.read<AppState>().deleteArtifact(a.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _onAction(_ArtifactAction action, Artifact a) {
    switch (action) {
      case _ArtifactAction.edit:
        _edit(context, a);
      case _ArtifactAction.copy:
        _copy(a);
      case _ArtifactAction.export:
        _export(a);
      case _ArtifactAction.reanalyze:
        _reanalyze(a);
      case _ArtifactAction.delete:
        _delete(a);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('产物')),
      body: FutureBuilder<Artifact?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final a = snap.data;
          if (a == null) return const Center(child: Text('产物不存在'));
          return _ArtifactBody(
            artifact: a,
            onAction: (action) => _onAction(action, a),
          );
        },
      ),
    );
  }
}

/// 产物正文：按信息架构分层渲染。
class _ArtifactBody extends StatelessWidget {
  const _ArtifactBody({required this.artifact, required this.onAction});
  final Artifact artifact;
  final ValueChanged<_ArtifactAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final a = artifact;
    final color = switch (a.type) {
      ArtifactType.resume => cs.primary,
      ArtifactType.weekly => cs.secondary,
      ArtifactType.interview => cs.tertiary,
    };
    final parsed = parseArtifactContent(a.content);
    final interview = a.type == ArtifactType.interview
        ? buildInterviewFeedbackView(a.content)
        : null;
    final showInterview = interview?.isStructured == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // P0：元信息 + 操作入口。
        Row(
          children: [
            Chip(
              label: Text(a.type.label),
              backgroundColor: color.withValues(alpha: 0.12),
              side: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${a.updatedAt.cnLabel} · 基于 ${a.sourceEntryIds.length} 条证据',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: cs.secondary),
              ),
            ),
            PopupMenuButton<_ArtifactAction>(
              tooltip: '更多操作',
              onSelected: onAction,
              itemBuilder: _menuItems,
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (showInterview) ...[
          // 结论卡。
          if (interview!.overall != null) ...[
            _OverallCard(overall: interview.overall!),
            const SizedBox(height: 12),
          ],
          // 证据状态（诚实统计）。
          _EvidenceStatusBar(view: interview),
          const SizedBox(height: 16),
          // 逐条点评折叠列表。
          if (interview.items.isNotEmpty) ...[
            _SectionLabel('逐条点评'),
            const SizedBox(height: 8),
            ...interview.items.asMap().entries.map((e) => _ItemCard(
                  item: e.value,
                  initiallyExpanded: e.key == 0,
                )),
            const SizedBox(height: 12),
          ],
          if (interview.hotspots.isNotEmpty) ...[
            _SectionLabel('热点与学习方向'),
            const SizedBox(height: 8),
            _BulletCard(lines: interview.hotspots, icon: Icons.trending_up),
            const SizedBox(height: 12),
          ],
          if (interview.topThree.isNotEmpty) ...[
            _SectionLabel('最该优先补强的三件事'),
            const SizedBox(height: 8),
            _NumberCard(lines: interview.topThree),
            const SizedBox(height: 12),
          ],
          // 未能识别的章节（兜底展示，不丢内容）。
          ..._genericSections(parsed, interview.otherSections, theme),
        ] else ...[
          if (parsed.preamble.isNotEmpty) ...[
            Text(parsed.preamble.join('\n'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
          ],
          ..._genericSections(parsed, parsed.sections, theme),
        ],

        const SizedBox(height: 8),
        // 原文核验（P3：原始内容作为详细信息）。
        _RawSection(content: a.content),
        const SizedBox(height: 16),
        // 免责声明移到底部。
        _AiDisclaimer(artifact: a),
      ],
    );
  }

  List<PopupMenuEntry<_ArtifactAction>> _menuItems(BuildContext ctx) => [
        const PopupMenuItem(
            value: _ArtifactAction.edit,
            child: ListTile(
                leading: Icon(Icons.edit_outlined), title: Text('编辑'))),
        const PopupMenuItem(
            value: _ArtifactAction.copy,
            child: ListTile(
                leading: Icon(Icons.copy_outlined), title: Text('复制内容'))),
        const PopupMenuItem(
            value: _ArtifactAction.export,
            child: ListTile(
                leading: Icon(Icons.ios_share), title: Text('导出 Markdown'))),
        const PopupMenuItem(
            value: _ArtifactAction.reanalyze,
            child: ListTile(
                leading: Icon(Icons.refresh), title: Text('重新分析'))),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _ArtifactAction.delete,
          child: ListTile(
            leading:
                Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
            title: Text('删除',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ),
      ];

  /// 通用章节列表：resume / weekly / 未识别的章节。
  List<Widget> _genericSections(
    ParsedArtifactContent parsed,
    List<ArtifactSection> sections,
    ThemeData theme,
  ) {
    if (sections.isEmpty) return const [];
    final result = <Widget>[];
    if (parsed.title != null) {
      result.add(Text(parsed.title!,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700)));
      result.add(const SizedBox(height: 4));
    }
    for (var i = 0; i < sections.length; i++) {
      result.add(_SectionCard(
          section: sections[i], initiallyExpanded: i == 0));
    }
    return result;
  }
}

/// 通用章节卡：折叠式。
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.initiallyExpanded});
  final ArtifactSection section;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(section.heading,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        children: [
          if (section.subsections.isNotEmpty)
            ...section.subsections.map((sub) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.title,
                          style: theme.textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ...sub.lines.map((l) => _BulletLine(text: l)),
                    ],
                  ),
                ))
          else
            ...section.lines.map((l) => _BulletLine(text: l)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(text,
        style: theme.textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700));
  }
}

/// P0：综合评价卡。
class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.overall});
  final String overall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.fact_check_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text('综合评价',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(overall,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}

/// 证据状态：只展示真实统计到的数量。
class _EvidenceStatusBar extends StatelessWidget {
  const _EvidenceStatusBar({required this.view});
  final InterviewFeedbackView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = view.items.length;
    final chips = <Widget>[
      _StatusChip(
          icon: Icons.topic_outlined,
          label: '逐条点评 $items 条',
          color: theme.colorScheme.secondary),
    ];
    if (view.pendingCount > 0) {
      chips.add(_StatusChip(
          icon: Icons.pending_outlined,
          label: '待补充 ${view.pendingCount} 处',
          color: const Color(0xFFC98A2D)));
    }
    if (view.shallowCount > 0) {
      chips.add(_StatusChip(
          icon: Icons.warning_amber_outlined,
          label: '偏浅提示 ${view.shallowCount} 处',
          color: theme.colorScheme.error));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// 逐条点评卡：折叠式，默认展开第一条。
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.initiallyExpanded});
  final InterviewItem item;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
          child: Icon(Icons.record_voice_over_outlined,
              size: 16, color: theme.colorScheme.secondary),
        ),
        title: Text(item.title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (item.effective?.isNotEmpty == true)
                _LabeledLine(
                    icon: Icons.circle_outlined,
                    label: '有效性',
                    text: item.effective!,
                    color: theme.colorScheme.onSurface),
              if (item.highlight?.isNotEmpty == true)
                _LabeledLine(
                    icon: Icons.check_circle_outline,
                    label: '亮点',
                    text: item.highlight!,
                    color: theme.colorScheme.primary),
              if (item.shallow?.isNotEmpty == true)
                _LabeledLine(
                    icon: Icons.warning_amber_outlined,
                    label: '偏浅处',
                    text: item.shallow!,
                    color: const Color(0xFFC98A2D)),
              if (item.expand?.isNotEmpty == true)
                _LabeledLine(
                    icon: Icons.arrow_outward,
                    label: '扩展建议',
                    text: item.expand!,
                    color: theme.colorScheme.secondary),
              ...item.rawLines.map((l) => _BulletLine(text: l)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// 带语义标签的一行（icon + label + 文本，不只靠颜色）。
class _LabeledLine extends StatelessWidget {
  const _LabeledLine({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                children: [
                  TextSpan(
                    text: '$label：',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用 bullet 行。
class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: theme.textTheme.bodyMedium),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// 卡片式列表（热点等）。
class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.lines, required this.icon});
  final List<String> lines;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: cs.secondary),
            const SizedBox(height: 6),
            ...lines.map((l) => _BulletLine(text: l)),
          ],
        ),
      ),
    );
  }
}

/// 编号列表卡（补强三件事等）。
class _NumberCard extends StatelessWidget {
  const _NumberCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...lines.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        child: Text('${e.key + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(e.value,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(height: 1.5)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// 原始 Markdown（折叠，供核验）。
class _RawSection extends StatelessWidget {
  const _RawSection({required this.content});
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading:
            Icon(Icons.menu_book_outlined, color: theme.colorScheme.secondary),
        title: const Text('原始分析（Markdown）'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              content.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部 AI 免责声明（不再抢占首屏）。
class _AiDisclaimer extends StatelessWidget {
  const _AiDisclaimer({required this.artifact});
  final Artifact artifact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lines = <String>[
      '以上内容由 AI 生成，未经人工核验；涉及能力判断的结论，请结合原始记录逐条验证。',
      ...artifact.gaps,
      ...artifact.risks,
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, size: 14, color: cs.outline),
            const SizedBox(width: 6),
            Text('AI 分析提示',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: cs.outline, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $l',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline, height: 1.4)),
              )),
        ],
      ),
    );
  }
}

class _ArtifactEditor extends StatefulWidget {
  const _ArtifactEditor({required this.artifact, required this.onSave});
  final Artifact artifact;
  final ValueChanged<String> onSave;

  @override
  State<_ArtifactEditor> createState() => _ArtifactEditorState();
}

class _ArtifactEditorState extends State<_ArtifactEditor> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.artifact.content);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('编辑产物',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            maxLines: 12,
            decoration: const InputDecoration(hintText: '编辑产物内容…'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消')),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  widget.onSave(_c.text);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}