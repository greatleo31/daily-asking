/// 工作室：搜索并选择证据，默认用 AI 生成简历要点 / 周报 / 面试反馈。
///
/// - AI 未配置时，点生成会强制引导先配置供应商（不可跳过）。
/// - 已配置时出站前必须展示披露（服务商/模型/路径/字段范围）。
/// - 生成结果标注：已有事实、缺失证据、风险提示。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../core/llm/llm_client.dart';
import '../../core/models.dart';
import '../../core/utils.dart';
import '../../settings/settings_page.dart';
import '../../settings/settings_repository.dart';
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

  List<Entry> _chosen(AppState state) =>
      state.allEntries.where((e) => _selected[e.id] == true).toList();

  /// 搜索过滤后的可见证据列表（作用于任务/背景/行动/结果/难点/标签）。
  List<Entry> _visible(AppState state) {
    final all = state.allEntries;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((e) =>
            '${e.task} ${e.context} ${e.action} ${e.result} ${e.blocker} '
                    '${e.tags.join()}'
                .toLowerCase()
                .contains(q))
        .toList();
  }

  bool _allVisibleSelected(AppState state) {
    final vis = _visible(state);
    return vis.isNotEmpty && vis.every((e) => _selected[e.id] == true);
  }

  /// 全选 / 全不选当前搜索过滤后的结果。
  void _toggleSelectAll(AppState state) {
    final vis = _visible(state);
    final select = !_allVisibleSelected(state);
    setState(() {
      for (final e in vis) {
        _selected[e.id] = select;
      }
    });
  }

  Future<void> _generate(ArtifactType type) async {
    final state = context.read<AppState>();
    final chosen = _chosen(state);
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择至少一条证据')));
      return;
    }

    // 需求3 强制配置门：未配置时不可生成，只能去配置供应商。
    if (!state.aiReady) {
      final go = await _showConfigureGuard(context);
      if (go != true || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AiConfigPage()),
      );
      return;
    }

    final settings = await state.settings.readLlmSettings();
    final apiKey = await _readApiKey();
    if (!mounted) return;
    final payload = OutboundPayload(entries: chosen, artifactType: type);
    final ok = await _confirmDisclosureAndKey(context, payload, settings);
    if (ok != true) return;
    setState(() => _busy = true);
    final client = OpenAiClient();
    final result = await client.complete(
      settings: settings,
      apiKey: apiKey!,
      system: payload.buildSystemPrompt(type),
      user: payload.buildUserMessage(),
    );
    setState(() => _busy = false);
    if (!mounted) return;
    if (result.isError) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    final artifact = Artifact(
      id: genId(prefix: 'a_'),
      type: type,
      content: result.content,
      sourceEntryIds: chosen.map((e) => e.id).toList(),
      risks: const ['AI 生成内容未经人工核对，请逐条验证。'],
      gaps: const ['AI 生成内容不保证覆盖全部缺失证据，请自行核对。'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await state.artifactRepo.save(artifact);
    await state.reload();
    if (!mounted) return;
    await _open(artifact.id);
  }

  /// 未配置 AI 时的强制引导（不可跳过：无取消按钮）。
  Future<bool?> _showConfigureGuard(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要先配置 AI 供应商'),
        content: const Text(
            '生成产物需要调用 AI，请先配置一个 OpenAI 兼容供应商'
            '（服务商 / Base URL / 模型 / API Key）。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  Future<String?> _readApiKey() async {
    // 通过 SettingsRepository 读取（不进入 Widget 状态，不回显，仅用于调用）。
    final state = context.read<AppState>();
    if (await state.settings.hasApiKey()) {
      return await state.settings.readApiKeyForCall();
    }
    return null;
  }

  Future<bool?> _confirmDisclosureAndKey(
      BuildContext context, OutboundPayload payload, LlmSettings settings) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('出站披露 · 确认后发送'),
        content: SingleChildScrollView(
          child: Text(payload.toDisclosure(settings),
              style: Theme.of(ctx).textTheme.bodySmall),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认发送')),
        ],
      ),
    );
  }

  Future<void> _open(String artifactId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArtifactViewPage(artifactId: artifactId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final visible = _visible(state);
    final content = ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('选择证据，生成简历要点 / 周报 / 面试反馈',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.secondary)),
          const SizedBox(height: 16),
          // 搜索栏。
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: '搜索证据…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '选择证据（${_chosen(state).length}/${state.allEntries.length}）',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (state.allEntries.isNotEmpty)
                TextButton(
                  onPressed: () => _toggleSelectAll(state),
                  child: Text(_allVisibleSelected(state) ? '全不选' : '全选'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.allEntries.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      color: theme.colorScheme.secondary),
                  const SizedBox(height: 8),
                  Text('还没有证据可选，先去「今日」记录一些吧。',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            )
          else if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.search_off, color: theme.colorScheme.secondary),
                  const SizedBox(height: 8),
                  Text('没有匹配"$_query"的证据',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            )
          else
            ...visible.map((e) => _SelectableEntry(
                  entry: e,
                  selected: _selected[e.id] == true,
                  onToggle: () => setState(() {
                    _selected[e.id] = !(_selected[e.id] == true);
                  }),
                )),
          const SizedBox(height: 24),
          Text('生成产物',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _GenButton(
            color: theme.colorScheme.primary,
            icon: Icons.assignment_outlined,
            title: '简历要点',
            subtitle: '把行动与结果整理成可投递的要点',
            busy: _busy,
            onTap: () => _generate(ArtifactType.resume),
          ),
          _GenButton(
            color: const Color(0xFFC98A2D),
            icon: Icons.calendar_view_week_outlined,
            title: '周报',
            subtitle: '按事项/结果/难点整理本周summary',
            busy: _busy,
            onTap: () => _generate(ArtifactType.weekly),
          ),
          _GenButton(
            color: const Color(0xFF2E6E7E),
            icon: Icons.question_answer_outlined,
            title: '面试反馈',
            subtitle: '像面试官看完你的所有工作一样，给出真实反馈与成长建议',
            busy: _busy,
            onTap: () => _generate(ArtifactType.interview),
          ),
          const SizedBox(height: 24),
          if (state.artifacts.isNotEmpty) ...[
            Text('已保存产物',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...state.artifacts.map((a) => _ArtifactTile(
                  artifact: a,
                  onTap: () => _open(a.id),
                )),
          ],
        ],
      );
    return widget.showAppBar
        ? Scaffold(
            appBar: AppBar(title: const Text('重新分析')),
            body: content,
          )
        : SafeArea(child: content);
  }
}

class _SelectableEntry extends StatelessWidget {
  const _SelectableEntry(
      {required this.entry, required this.selected, required this.onToggle});
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
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.task,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(entry.date.cnLabel,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.secondary)),
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
  const _GenButton(
      {required this.color,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.busy,
      required this.onTap});
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: busy ? null : onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, color: color),
        ),
        title: Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.secondary)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _ArtifactTile extends StatelessWidget {
  const _ArtifactTile({required this.artifact, required this.onTap});
  final Artifact artifact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (artifact.type) {
      ArtifactType.resume => theme.colorScheme.primary,
      ArtifactType.weekly => const Color(0xFFC98A2D),
      ArtifactType.interview => const Color(0xFF2E6E7E),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(Icons.description_outlined, color: color),
        title: Text('${artifact.type.label} · ${artifact.updatedAt.cnLabel}'),
        subtitle: Text(
          '${artifact.content.length} 字',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.secondary),
        ),
      ),
    );
  }
}
