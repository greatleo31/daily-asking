/// 产物查看/编辑页：展示已有事实、缺失证据、风险提示，可编辑并保存。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/models.dart';

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
    _future = context.read<AppState>().artifactRepo.find(widget.artifactId);
  }

  Future<void> _saveEdited(Artifact a) async {
    await context.read<AppState>().updateArtifact(a);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
    }
  }

  Future<void> _delete(BuildContext context, Artifact a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这份产物？'),
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
      await this.context.read<AppState>().deleteArtifact(a.id);
      if (mounted) Navigator.of(this.context).pop();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          final color = switch (a.type) {
            ArtifactType.resume => theme.colorScheme.primary,
            ArtifactType.weekly => const Color(0xFFC98A2D),
            ArtifactType.interview => const Color(0xFF2E6E7E),
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(a.type.label),
                    backgroundColor: color.withValues(alpha: 0.12),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _edit(context, a),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: '编辑',
                  ),
                  IconButton(
                    onPressed: () => _delete(context, a),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    tooltip: '删除',
                  ),
                ],
              ),
              if (a.gaps.isNotEmpty) ...[
                _Notice(
                  color: const Color(0xFFC98A2D),
                  icon: Icons.warning_amber_outlined,
                  title: '缺失证据',
                  lines: a.gaps,
                ),
                const SizedBox(height: 12),
              ],
              if (a.risks.isNotEmpty) ...[
                _Notice(
                  color: const Color(0xFFB8452F),
                  icon: Icons.error_outline,
                  title: '风险提示',
                  lines: a.risks,
                ),
                const SizedBox(height: 12),
              ],
              Text('产物内容',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.secondary)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  a.content,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(
      {required this.color,
      required this.icon,
      required this.title,
      required this.lines});
  final Color color;
  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $l',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurface)),
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