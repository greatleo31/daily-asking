/// 产物只读 Markdown 阅读器：渲染 API 原文，并为每个顶层块提供原文复制。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/export/markdown_exporter.dart';
import '../../core/models.dart';
import '../../core/utils.dart';
import 'artifact_generation.dart';
import 'markdown_document.dart';
import 'studio_page.dart';

enum _ArtifactAction { copyMarkdown, copyReadable, download, reanalyze, delete }

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
    _future = context.read<AppState>().findArtifact(widget.artifactId);
  }

  Future<void> _copyMarkdown(Artifact artifact) async {
    await Clipboard.setData(
      ClipboardData(text: artifactMarkdownSource(artifact)),
    );
    _showMessage('已复制 Markdown 原文');
  }

  Future<void> _copyReadable(Artifact artifact) async {
    final document = parseMarkdownDocument(artifactMarkdownSource(artifact));
    await Clipboard.setData(ClipboardData(text: document.toReadableText()));
    _showMessage('已复制可读文本');
  }

  Future<void> _download(Artifact artifact) async {
    final ok = await MarkdownShare.share(
      fileName: artifactFileName(artifact, DateTime.now()),
      content: artifactMarkdownSource(artifact),
    );
    _showMessage(ok ? '已下载并唤起分享' : '下载失败，请重试');
  }

  Future<void> _reanalyze(Artifact artifact) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudioPage(
          initialEntryIds: artifact.sourceEntryIds,
          showAppBar: true,
        ),
      ),
    );
  }

  Future<void> _delete(Artifact artifact) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这份产物？'),
        content: const Text('删除后无法恢复'),
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
    if (mounted) Navigator.of(context).pop();
  }

  void _onAction(_ArtifactAction action, Artifact artifact) {
    switch (action) {
      case _ArtifactAction.copyMarkdown:
        _copyMarkdown(artifact);
      case _ArtifactAction.copyReadable:
        _copyReadable(artifact);
      case _ArtifactAction.download:
        _download(artifact);
      case _ArtifactAction.reanalyze:
        _reanalyze(artifact);
      case _ArtifactAction.delete:
        _delete(artifact);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('产物')),
      body: FutureBuilder<Artifact?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final artifact = snapshot.data;
          if (artifact == null) return const Center(child: Text('产物不存在'));
          return _ArtifactBody(
            artifact: artifact,
            onAction: (action) => _onAction(action, artifact),
          );
        },
      ),
    );
  }
}

class _ArtifactBody extends StatelessWidget {
  const _ArtifactBody({required this.artifact, required this.onAction});

  final Artifact artifact;
  final ValueChanged<_ArtifactAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (artifact.type) {
      ArtifactType.resume => theme.colorScheme.primary,
      ArtifactType.weekly => const Color(0xFFC98A2D),
      ArtifactType.interview => const Color(0xFF2E6E7E),
    };
    final entries = context.select((AppState state) => state.allEntries);
    final document = parseMarkdownDocument(artifactMarkdownSource(artifact));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Row(
          children: [
            Chip(
              label: Text(artifact.type.label),
              backgroundColor: color.withValues(alpha: 0.12),
              side: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${artifact.updatedAt.cnLabel}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            PopupMenuButton<_ArtifactAction>(
              tooltip: '更多操作',
              onSelected: onAction,
              itemBuilder: _menuItems,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const _AiHint(),
        if (isArtifactStale(artifact, entries)) ...[
          const SizedBox(height: 12),
          const _StaleBanner(),
        ],
        const SizedBox(height: 18),
        if (document.blocks.isEmpty)
          const _EmptyMarkdown()
        else
          ...document.blocks.map((block) => _MarkdownBlockView(block: block)),
      ],
    );
  }

  List<PopupMenuEntry<_ArtifactAction>> _menuItems(BuildContext context) => [
    const PopupMenuItem(
      value: _ArtifactAction.copyMarkdown,
      child: ListTile(
        leading: Icon(Icons.content_copy_outlined),
        title: Text('复制 Markdown 原文'),
      ),
    ),
    const PopupMenuItem(
      value: _ArtifactAction.copyReadable,
      child: ListTile(
        leading: Icon(Icons.subject_outlined),
        title: Text('复制可读文本'),
      ),
    ),
    const PopupMenuItem(
      value: _ArtifactAction.download,
      child: ListTile(
        leading: Icon(Icons.download_outlined),
        title: Text('下载 Markdown'),
      ),
    ),
    const PopupMenuItem(
      value: _ArtifactAction.reanalyze,
      child: ListTile(leading: Icon(Icons.refresh), title: Text('重新分析')),
    ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: _ArtifactAction.delete,
      child: ListTile(
        leading: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          '删除',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ),
  ];
}

class _MarkdownBlockView extends StatelessWidget {
  const _MarkdownBlockView({required this.block});

  final MarkdownBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (block.type == MarkdownBlockType.thematicBreak) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Divider(color: cs.outlineVariant)),
            _CopyBlockButton(raw: block.copyText),
          ],
        ),
      );
    }

    final sheet = _markdownStyleSheet(theme);
    // 标题块只展示渲染结果，不提供块级复制（整篇「复制可读文本」仍含标题结构）。
    // 直接 Markdown 渲染，不套卡片/开片壳。
    final showCopy = block.type != MarkdownBlockType.heading;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: MarkdownBody(
              data: block.raw,
              styleSheet: sheet,
              shrinkWrap: true,
            ),
          ),
          if (showCopy) _CopyBlockButton(raw: block.copyText),
        ],
      ),
    );
  }
}

MarkdownStyleSheet _markdownStyleSheet(ThemeData theme) {
  final textTheme = theme.textTheme;
  final cs = theme.colorScheme;
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: textTheme.bodyLarge?.copyWith(
      height: 1.65,
      color: cs.onSurface,
    ),
    h1: textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.3,
      color: cs.onSurface,
      letterSpacing: -0.2,
    ),
    h2: textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.4,
      color: cs.primary,
      letterSpacing: -0.1,
    ),
    h3: textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.45,
      color: cs.onSurface,
    ),
    blockSpacing: 0,
    listIndent: 22,
    listBullet: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
    blockquoteDecoration: BoxDecoration(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    codeblockDecoration: BoxDecoration(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(12),
  );
}

class _CopyBlockButton extends StatelessWidget {
  const _CopyBlockButton({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '复制此段 Markdown',
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      color: Theme.of(context).colorScheme.outline,
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: raw));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('已复制此段 Markdown')));
      },
      icon: const Icon(Icons.content_copy_outlined),
    );
  }
}

class _AiHint extends StatelessWidget {
  const _AiHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'AI 可能会犯错，请认真检查',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.update_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '来源记录已更新，这份产物可能已经过期，请重新分析后再使用',
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMarkdown extends StatelessWidget {
  const _EmptyMarkdown();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        '无内容',
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}