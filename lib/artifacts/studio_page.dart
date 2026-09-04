/// 工作室：选择证据生成 Markdown 产物，并提供轻量虚拟文件库。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/export/markdown_exporter.dart';
import '../../core/llm/llm_client.dart';
import '../../core/models.dart';
import '../../core/utils.dart';
import '../../settings/settings_page.dart';
import 'artifact_generation.dart';
import 'artifact_library.dart';
import 'artifact_view_page.dart';

class StudioPage extends StatefulWidget {
  const StudioPage({
    super.key,
    this.initialEntryIds = const [],
    this.showAppBar = false,
  });

  final List<String> initialEntryIds;
  final bool showAppBar;

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  final Map<String, bool> _selected = {};
  final _search = TextEditingController();
  String _query = '';
  bool _busy = false;
  ArtifactLibraryFolder _folder = ArtifactLibraryFolder.all;
  ArtifactSortField _sortField = ArtifactSortField.date;
  bool _ascending = false;
  String? _lastCreatedArtifactId;

  @override
  void initState() {
    super.initState();
    for (final id in widget.initialEntryIds) {
      _selected[id] = true;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Entry> _chosen(List<Entry> allEntries) =>
      allEntries.where((entry) => _selected[entry.id] == true).toList();

  List<Entry> _visibleEntries(List<Entry> allEntries) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return allEntries;
    return allEntries
        .where(
          (entry) =>
              '${entry.task} ${entry.context} ${entry.action} ${entry.result} '
                      '${entry.blocker} ${entry.tags.join()}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
  }

  List<Artifact> _visibleArtifacts(List<Artifact> artifacts) {
    final filtered = filterArtifacts(artifacts, _folder);
    return sortArtifacts(filtered, _sortField, ascending: _ascending);
  }

  bool _allVisibleSelected(List<Entry> allEntries) {
    final visible = _visibleEntries(allEntries);
    return visible.isNotEmpty &&
        visible.every((entry) => _selected[entry.id] == true);
  }

  void _toggleSelectAll(List<Entry> allEntries) {
    final visible = _visibleEntries(allEntries);
    final select = !_allVisibleSelected(allEntries);
    setState(() {
      for (final entry in visible) {
        _selected[entry.id] = select;
      }
    });
  }

  Future<void> _generate(ArtifactType type) async {
    final state = context.read<AppState>();
    final chosen = _chosen(state.allEntries);
    if (chosen.isEmpty) {
      _showMessage('请先选择至少一条记录');
      return;
    }
    if (!state.aiReady) {
      final go = await _showConfigureGuard(context);
      if (go != true || !mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AiConfigPage()));
      return;
    }

    final settings = await state.readLlmSettings();
    final apiKey = await state.readApiKeyForCall();
    if (!mounted || apiKey == null) return;
    final payload = OutboundPayload(entries: chosen, artifactType: type);
    final ok = await _confirmDisclosure(context, payload);
    if (ok != true) return;

    setState(() => _busy = true);
    final generatedAt = DateTime.now();
    final result = await OpenAiClient().complete(
      settings: settings,
      apiKey: apiKey,
      system: payload.buildSystemPrompt(type),
      user: payload.buildUserMessage(referenceDate: generatedAt),
    );
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;
    if (result.isError) {
      _showMessage(result.error!);
      return;
    }

    final artifact = buildGeneratedArtifact(
      id: genId(prefix: 'a_'),
      type: type,
      rawContent: result.content,
      sourceEntries: chosen,
      generatedAt: generatedAt,
    );
    await state.updateArtifact(artifact);
    if (!mounted) return;
    setState(() => _lastCreatedArtifactId = artifact.id);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _lastCreatedArtifactId == artifact.id) {
        setState(() => _lastCreatedArtifactId = null);
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    await _open(artifact.id);
  }

  Future<bool?> _showConfigureGuard(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('需要先配置 AI 供应商'),
      content: const Text('生成产物需要调用 AI，请先配置一个 OpenAI 兼容供应商'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('去配置'),
        ),
      ],
    ),
  );

  Future<bool?> _confirmDisclosure(
    BuildContext context,
    OutboundPayload payload,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('访问 AI 服务'),
        content: Text(
          payload.toDisclosure(),
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认访问'),
          ),
        ],
      ),
    );
  }

  Future<void> _open(String artifactId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArtifactViewPage(artifactId: artifactId),
      ),
    );
  }

  Future<void> _downloadArtifact(Artifact artifact) async {
    final ok = await MarkdownShare.share(
      fileName: artifactFileName(artifact, DateTime.now()),
      content: artifactMarkdownSource(artifact),
    );
    if (mounted) _showMessage(ok ? '已下载并唤起分享' : '下载失败，请重试');
  }

  Future<void> _deleteArtifact(Artifact artifact) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这份产物？'),
        content: Text('“${artifactDisplayName(artifact)}”删除后无法恢复'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
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
    if (ok != true || !mounted) return;
    await context.read<AppState>().deleteArtifact(artifact.id);
    _showMessage('已删除');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectFolder(ArtifactLibraryFolder folder) {
    setState(() => _folder = folder);
  }

  void _selectSort(_SortSelection option) {
    setState(() {
      _sortField = option.field;
      _ascending = option.ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = context.select((AppState state) => state.allEntries);
    final artifacts = context.select((AppState state) => state.artifacts);
    final theme = Theme.of(context);
    final visibleEntries = _visibleEntries(allEntries);
    final visibleArtifacts = _visibleArtifacts(artifacts);
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _ArtifactLibraryHeader(
          folder: _folder,
          sortField: _sortField,
          ascending: _ascending,
          onFolderChanged: _selectFolder,
          onSortSelected: _selectSort,
        ),
        const SizedBox(height: 14),
        _ArtifactLibraryList(
          artifacts: visibleArtifacts,
          highlightedId: _lastCreatedArtifactId,
          onOpen: _open,
          onDownload: _downloadArtifact,
          onDelete: _deleteArtifact,
        ),
        const SizedBox(height: 24),
        Text(
          '选择记录生成新产物',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: '搜索记录…',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '选择记录（${_chosen(allEntries).length}/${allEntries.length}）',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (allEntries.isNotEmpty)
              TextButton(
                onPressed: () => _toggleSelectAll(allEntries),
                child: Text(_allVisibleSelected(allEntries) ? '全不选' : '全选'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (allEntries.isEmpty)
          const _EntryEmptyState()
        else if (visibleEntries.isEmpty)
          _EntryEmptyState(query: _query)
        else
          ...visibleEntries.map(
            (entry) => _SelectableEntry(
              entry: entry,
              selected: _selected[entry.id] == true,
              onToggle: () => setState(() {
                _selected[entry.id] = !(_selected[entry.id] == true);
              }),
            ),
          ),
        const SizedBox(height: 18),
        Text(
          '生成产物',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _GenButton(
          color: theme.colorScheme.primary,
          icon: Icons.assignment_outlined,
          title: '简历要点',
          subtitle: '整理成可投递的要点',
          busy: _busy,
          onTap: () => _generate(ArtifactType.resume),
        ),
        _GenButton(
          color: const Color(0xFFC98A2D),
          icon: Icons.calendar_view_week_outlined,
          title: '周报',
          subtitle: '整理工作进展',
          busy: _busy,
          onTap: () => _generate(ArtifactType.weekly),
        ),
        _GenButton(
          color: const Color(0xFF2E6E7E),
          icon: Icons.question_answer_outlined,
          title: '面试反馈',
          subtitle: '反馈亮点、偏浅处和方向',
          busy: _busy,
          onTap: () => _generate(ArtifactType.interview),
        ),
      ],
    );
    return widget.showAppBar
        ? Scaffold(
            appBar: AppBar(title: const Text('重新分析')),
            body: body,
          )
        : SafeArea(child: body);
  }
}

typedef _SortSelection = ({ArtifactSortField field, bool ascending});

class _ArtifactLibraryHeader extends StatelessWidget {
  const _ArtifactLibraryHeader({
    required this.folder,
    required this.sortField,
    required this.ascending,
    required this.onFolderChanged,
    required this.onSortSelected,
  });

  final ArtifactLibraryFolder folder;
  final ArtifactSortField sortField;
  final bool ascending;
  final ValueChanged<ArtifactLibraryFolder> onFolderChanged;
  final ValueChanged<_SortSelection> onSortSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '产物库',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<ArtifactSortField>(
                segments: [
                  for (final field in ArtifactSortField.values)
                    ButtonSegment(value: field, label: Text(field.label)),
                ],
                selected: {sortField},
                showSelectedIcon: true,
                onSelectionChanged: (selection) => onSortSelected(
                  (field: selection.first, ascending: ascending),
                ),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: ascending ? '切换为降序' : '切换为升序',
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  onSortSelected((field: sortField, ascending: !ascending)),
              icon: Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ArtifactLibraryFolder.values.map((item) {
              final selected = item == folder;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  avatar: Icon(
                    selected ? Icons.check : _folderIcon(item),
                    size: 17,
                  ),
                  label: Text(item.label),
                  onSelected: (_) => onFolderChanged(item),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  IconData _folderIcon(ArtifactLibraryFolder folder) => switch (folder) {
    ArtifactLibraryFolder.all => Icons.folder_open_outlined,
    ArtifactLibraryFolder.resume => Icons.assignment_outlined,
    ArtifactLibraryFolder.weekly => Icons.calendar_view_week_outlined,
    ArtifactLibraryFolder.interview => Icons.question_answer_outlined,
  };
}

class _ArtifactLibraryList extends StatelessWidget {
  const _ArtifactLibraryList({
    required this.artifacts,
    required this.highlightedId,
    required this.onOpen,
    required this.onDownload,
    required this.onDelete,
  });

  final List<Artifact> artifacts;
  final String? highlightedId;
  final ValueChanged<String> onOpen;
  final ValueChanged<Artifact> onDownload;
  final ValueChanged<Artifact> onDelete;

  @override
  Widget build(BuildContext context) {
    if (artifacts.isEmpty) return const _LibraryEmptyState();
    return Column(
      children: artifacts
          .map(
            (artifact) => _ArtifactTile(
              artifact: artifact,
              highlighted: artifact.id == highlightedId,
              onTap: () => onOpen(artifact.id),
              onDownload: () => onDownload(artifact),
              onDelete: () => onDelete(artifact),
            ),
          )
          .toList(),
    );
  }
}

class _ArtifactTile extends StatelessWidget {
  const _ArtifactTile({
    required this.artifact,
    required this.highlighted,
    required this.onTap,
    required this.onDownload,
    required this.onDelete,
  });

  final Artifact artifact;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (artifact.type) {
      ArtifactType.resume => theme.colorScheme.primary,
      ArtifactType.weekly => const Color(0xFFC98A2D),
      ArtifactType.interview => const Color(0xFF2E6E7E),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.12)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? color.withValues(alpha: 0.55)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(Icons.description_outlined, color: color),
        title: Text(
          artifactDisplayName(artifact),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${artifact.type.label} · ${artifact.updatedAt.cnLabel}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        trailing: PopupMenuButton<_ArtifactFileAction>(
          tooltip: '文件操作',
          onSelected: (action) {
            switch (action) {
              case _ArtifactFileAction.view:
                onTap();
              case _ArtifactFileAction.download:
                onDownload();
              case _ArtifactFileAction.delete:
                onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _ArtifactFileAction.view,
              child: ListTile(
                leading: Icon(Icons.visibility_outlined),
                title: Text('查看'),
              ),
            ),
            PopupMenuItem(
              value: _ArtifactFileAction.download,
              child: ListTile(
                leading: Icon(Icons.download_outlined),
                title: Text('下载 Markdown'),
              ),
            ),
            PopupMenuItem(
              value: _ArtifactFileAction.delete,
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('删除'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ArtifactFileAction { view, download, delete }

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      '这个目录还没有产物，生成后会自动收纳到这里',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _EntryEmptyState extends StatelessWidget {
  const _EntryEmptyState({this.query});
  final String? query;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(
          query == null ? Icons.inbox_outlined : Icons.search_off,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 8),
        Text(
          query == null ? '还没有记录可选，先去「今日」记录一些吧' : '没有匹配“$query”的记录',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _SelectableEntry extends StatelessWidget {
  const _SelectableEntry({
    required this.entry,
    required this.selected,
    required this.onToggle,
  });

  final Entry entry;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : null,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.task,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.date.cnLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenButton extends StatelessWidget {
  const _GenButton({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: busy ? null : onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}
