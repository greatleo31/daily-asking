/// 工作室：选择证据生成 Markdown 产物，并提供轻量虚拟文件库。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../companion/companion_scene_card.dart';
import '../../core/export/markdown_exporter.dart';
import '../../core/llm/llm_client.dart';
import '../../core/models.dart';
import '../../core/utils.dart';
import '../../settings/settings_page.dart';
import '../../settings/settings_repository.dart';
import 'artifact_generation.dart';
import 'artifact_library.dart';
import 'artifact_view_page.dart';
import 'generation_waiting_overlay.dart';

/// 生成调用函数签名（与 [OpenAiClient.complete] 一致）。生产默认走真实客户端；
/// 测试可注入替身；BYOK 出站披露仍由页面流程统一处理，本 seam 不绕过。
typedef GenerationCall =
    Future<LlmResult> Function({
      required LlmSettings settings,
      required String apiKey,
      required String system,
      required String user,
    });

class StudioPage extends StatefulWidget {
  const StudioPage({
    super.key,
    this.initialEntryIds = const [],
    this.showAppBar = false,
    this.generationCall,
  });

  final List<String> initialEntryIds;
  final bool showAppBar;

  /// 测试 seam：缺省为真实 [OpenAiClient.complete]。
  final GenerationCall? generationCall;

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  final Map<String, bool> _selected = {};
  final _search = TextEditingController();
  String _query = '';
  ArtifactType? _generatingType;
  ArtifactLibraryFolder _folder = ArtifactLibraryFolder.all;
  ArtifactSortField _sortField = ArtifactSortField.date;
  bool _ascending = false;
  String? _lastCreatedArtifactId;
  _WaitingOverlaySession? _waiting;
  bool _waitingDismissed = false;

  @override
  void initState() {
    super.initState();
    for (final id in widget.initialEntryIds) {
      _selected[id] = true;
    }
  }

  @override
  void dispose() {
    final waiting = _waiting;
    if (waiting != null) {
      _waiting = null;
      // 页面销毁时收尾残留的全屏蒙层，避免遮罩留在屏幕上。
      WidgetsBinding.instance.addPostFrameCallback((_) => waiting.close());
    }
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
    if (ok != true || !mounted) return;

    setState(() {
      _generatingType = type;
      _waitingDismissed = false;
    });
    _showWaitingOverlay(type);
    final waiting = _waiting;
    final generatedAt = DateTime.now();
    LlmResult result;
    try {
      final call = widget.generationCall ?? OpenAiClient().complete;
      result = await call(
        settings: settings,
        apiKey: apiKey,
        system: payload.buildSystemPrompt(type),
        user: payload.buildUserMessage(referenceDate: generatedAt),
      );
    } finally {
      if (mounted) setState(() => _generatingType = null);
    }
    if (!mounted) {
      await _closeWaitingOverlay();
      return;
    }
    if (result.isError) {
      await _closeWaitingOverlay();
      if (!mounted) return;
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
    if (!mounted) {
      await _closeWaitingOverlay();
      return;
    }
    setState(() => _lastCreatedArtifactId = artifact.id);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _lastCreatedArtifactId == artifact.id) {
        setState(() => _lastCreatedArtifactId = null);
      }
    });

    if (waiting != null && waiting.userDismissed) {
      // 用户已点开空白处退到内嵌画报大卡片：只提示任务完成，不打断当前视线。
      _waiting = null;
      _showMessage(
        '「${type.label}」已生成',
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            _open(artifact.id);
          },
        ),
      );
      return;
    }

    // 用户仍停留在全屏等待：收起蒙层后平滑切换到 Markdown 产物页。
    await _closeWaitingOverlay();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    await _open(artifact.id);
  }

  /// 展示全屏等待蒙层；用户主动关闭时只记录状态，蒙层自身负责退出。
  void _showWaitingOverlay(ArtifactType type) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final session = _WaitingOverlaySession(navigator);
    _waiting = session;
    // 蒙层是进入等待时的一次快照，读一次即可，无需订阅变化。
    final companion = context.read<AppState>();
    final stage = companion.companionStage;
    final profile = companion.companion;
    final route = PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => GenerationWaitingOverlay(
        type: type,
        stage: stage,
        name: profile.name,
        onDismiss: () {
          session.userDismissed = true;
          if (mounted) setState(() => _waitingDismissed = true);
        },
      ),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
    session.attach(route);
    session.pushed = navigator.push(route);
  }

  /// 收起全屏等待蒙层，并等待淡出结束，保证后续页面切换平滑。
  Future<void> _closeWaitingOverlay() async {
    final session = _waiting;
    _waiting = null;
    if (session == null) return;
    session.close();
    await session.pushed;
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

  void _showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
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
        if (_generatingType != null)
          _GenerationWaitingCard(
            type: _generatingType!,
            autoOpen: !_waitingDismissed,
          ),
        _GenButton(
          color: theme.colorScheme.primary,
          icon: Icons.assignment_outlined,
          title: '简历要点',
          subtitle: '整理成可投递的要点',
          enabled: _generatingType == null,
          onTap: () => _generate(ArtifactType.resume),
        ),
        _GenButton(
          color: const Color(0xFFC98A2D),
          icon: Icons.calendar_view_week_outlined,
          title: '周报',
          subtitle: '整理工作进展',
          enabled: _generatingType == null,
          onTap: () => _generate(ArtifactType.weekly),
        ),
        _GenButton(
          color: const Color(0xFF2E6E7E),
          icon: Icons.question_answer_outlined,
          title: '面试反馈',
          subtitle: '反馈亮点、偏浅处和方向',
          enabled: _generatingType == null,
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
        Row(
          children: [
            Expanded(
              child: Text(
                '产物库',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SegmentedButton<ArtifactSortField>(
              segments: [
                for (final field in ArtifactSortField.values)
                  ButtonSegment(value: field, label: Text(field.label)),
              ],
              selected: {sortField},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => onSortSelected(
                (field: selection.first, ascending: ascending),
              ),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: ascending ? '切换为降序' : '切换为升序',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () =>
                  onSortSelected((field: sortField, ascending: !ascending)),
              icon: Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ArtifactLibraryFolder.values.map((item) {
              final selected = item == folder;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
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
      // 高亮态给容器上了底色，ListTile 的水波纹需落在自己的 Material 上。
      child: Material(
        type: MaterialType.transparency,
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

class _GenerationWaitingCard extends StatelessWidget {
  const _GenerationWaitingCard({required this.type, required this.autoOpen});

  final ArtifactType type;

  /// 用户是否仍停留在全屏等待蒙层（否则完成后只提示、不再自动打开产物）。
  final bool autoOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = context.select((AppState s) => s.companionStage);
    final profile = context.select((AppState s) => s.companion);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanionSceneCard(
            stage: stage,
            name: profile.name,
            statusText: '正在生成「${type.label}」…',
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              autoOpen ? '整理记录中，完成后会自动打开产物。' : '整理记录中…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        ],
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
    required this.enabled,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: enabled ? 0.15 : 0.08),
        child: Icon(icon, color: color.withValues(alpha: enabled ? 1 : 0.4)),
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

/// 全屏等待蒙层在页面侧的一次会话：记录路由、用户是否主动关闭，
/// 以及在生成完成时安全地收起蒙层（只收起自己压在最上层的那一次）。
class _WaitingOverlaySession {
  _WaitingOverlaySession(this.navigator);

  final NavigatorState navigator;
  Route<void>? _route;

  /// 蒙层路由被弹出后完成的 future，用于等待淡出动画结束。
  Future<void>? pushed;

  /// 用户是否主动关闭了蒙层。
  bool userDismissed = false;

  void attach(Route<void> route) => _route = route;

  void close() {
    final route = _route;
    if (route == null || !route.isActive || !route.isCurrent) return;
    navigator.pop();
  }
}
