/// 今日：快速记录一句话事实 → 保存 → 本地追问。
///
/// 不允许因未回答追问而阻止保存；追问可回答 / 跳过。
/// 答或跳成功后在本页连续展示下一问（同时最多一卡），无剩余则停止。
/// 顶部为本地晨昏伙伴主视觉：只读快照展示 + 点击展开成长卡；
/// 保存成功后伙伴才成长并播放克制的舒展回应，失败保持原状。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../companion/companion_profile.dart';
import '../../companion/companion_service.dart';
import '../../core/models.dart';
import '../../core/utils.dart';
import '../evidence/evidence_detail_page.dart';
import '../evidence/question_card.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _controller = TextEditingController();

  /// 保存成功计数：递增后伙伴播放一次舒展回应（失败不递增）。
  int _stretchTrigger = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(BuildContext context) async {
    final state = context.read<AppState>();
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _snack('先写一句今天发生的真实小事吧');
      return;
    }
    _controller.clear();
    try {
      final q = await state.saveQuickToday(text);
      if (!mounted) return;
      final event = state.lastCompanionEvent;
      // 每条成功保存的 Entry 都触发一次轻微舒展回应（同日重复保存也触发）。
      setState(() => _stretchTrigger++);
      if (event?.milestone != null) {
        // 节点提示：阶段变化 + 节点语录；节点语录不可换句。
        if (q != null) {
          await _showQuestionDialog(this.context, q);
          if (!mounted) return;
        }
        _snack('第 ${event!.milestone} 天 · ${event.quote ?? ''}');
      } else if (q != null) {
        await _showQuestionDialog(this.context, q);
      } else {
        _snack('已保存 ✓');
      }
    } on SaveRollbackIncomplete {
      // 写入失败且回滚未完成：状态不确定，不得恢复输入、不得提示可重试。
      if (!mounted) return;
      _snack('保存状态不确定，请先刷新确认，暂不要重复提交');
    } on SaveSucceededButRefreshFailed {
      // 数据已落盘但界面刷新失败：不恢复输入（避免重试造成重复 Entry），
      // 提示真实状态，等待下次刷新恢复。
      if (!mounted) return;
      _snack('已保存，但界面刷新失败，请稍后刷新查看');
    } catch (_) {
      // 保存失败：伙伴保持原阶段与天数，恢复输入等待重试，不播放成长动画。
      if (!mounted) return;
      _controller.text = text;
      _snack('保存失败，请稍后重试');
    }
  }

  Future<void> _showQuestionDialog(
      BuildContext context, EvidenceQuestion q) async {
    EvidenceQuestion? current = q;
    while (current != null && mounted) {
      final next = await showModalBottomSheet<EvidenceQuestion?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => QuestionCard(question: current!),
      );
      current = next;
    }
  }

  void _openGrowthCard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CompanionGrowthCard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            DateTime.now().cnLabel,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.secondary),
          ),
          const SizedBox(height: 16),
          _CompanionHero(
            profile: state.companion,
            stage: state.companionStage,
            stretchTrigger: _stretchTrigger,
            onTap: _openGrowthCard,
          ),
          const SizedBox(height: 16),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  maxLines: 3,
                  minLines: 2,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: '请输入精简概括',
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
          const _TodayOverview(),
        ],
      ),
    );
  }
}

/// 伙伴主视觉：素材整图切换 + 成功保存后的低幅度舒展回应。
///
/// 阶段切换用轻量淡入淡出；`MediaQuery.disableAnimations` 启用时直接展示
/// 最终图，不播放任何动画。只接收不可变快照，不直接读 Repository。
class _CompanionHero extends StatefulWidget {
  const _CompanionHero({
    required this.profile,
    required this.stage,
    required this.stretchTrigger,
    required this.onTap,
  });

  final CompanionProfile profile;
  final CompanionStage stage;
  final int stretchTrigger;
  final VoidCallback onTap;

  @override
  State<_CompanionHero> createState() => _CompanionHeroState();
}

class _CompanionHeroState extends State<_CompanionHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _stretch;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _stretch = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _CompanionHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stretchTrigger != oldWidget.stretchTrigger) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1.0; // 减少动画：直接展示最终图
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dayCopy = widget.profile.growthDays == 0
        ? CompanionService.preRecordCopy
        : '一起留下了 ${widget.profile.growthDays} 天';
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: ScaleTransition(
                scale: _stretch,
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  child: Image.asset(
                    widget.stage.assetPath,
                    key: ValueKey(widget.stage.assetPath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.spa_outlined, size: 48),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.stage.label,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          color: theme.colorScheme.secondary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dayCopy,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '点击展开成长卡',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 成长卡：当前阶段、累计成长日、当前语录、下一节点，以及命名入口。
///
/// 以底部弹层展示，关闭不触碰输入控制器，用户输入保持不变。
class _CompanionGrowthCard extends StatefulWidget {
  const _CompanionGrowthCard();

  @override
  State<_CompanionGrowthCard> createState() => _CompanionGrowthCardState();
}

class _CompanionGrowthCardState extends State<_CompanionGrowthCard> {
  final _nameController = TextEditingController();
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitName() async {
    final state = context.read<AppState>();
    final error = await state.setCompanionName(_nameController.text);
    if (!mounted) return;
    setState(() {
      _nameError = error;
      if (error == null) _nameController.clear();
    });
  }

  Future<void> _rename() async {
    final state = context.read<AppState>();
    final controller = TextEditingController(text: state.companion.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改伙伴名称'),
        content: TextField(
          controller: controller,
          maxLength: 8,
          decoration: const InputDecoration(hintText: '1–8 个中文或英文字符'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认修改'),
          ),
        ],
      ),
    );
    final text = controller.text;
    controller.dispose();
    if (ok != true || !mounted) return;
    // 修改名称要求明确确认后才保存。
    final error = await state.setCompanionName(text);
    if (mounted && error != null) setState(() => _nameError = error);
  }

  Future<void> _reroll() async {
    await context.read<AppState>().rerollCompanionQuote();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final profile = state.companion;
    final stage = state.companionStage;
    final quote = state.companionQuote;
    final isNode = state.companionQuoteIsNode;
    final canReroll = state.companionCanReroll;
    final next = state.companionNextMilestone;
    final nextCopy =
        next == null ? '已抵达第 30 天，继续积累' : '第 $next 天';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 64,
                    height: 64,
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    child: Image.asset(
                      stage.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.spa_outlined, size: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name ?? '晨昏伙伴',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.growthDays == 0
                            ? CompanionService.preRecordCopy
                            : '${stage.label} · 一起留下了 ${profile.growthDays} 天',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '今日语录',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.secondary),
                      ),
                      const Spacer(),
                      if (isNode)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '节点语录',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.secondary),
                          ),
                        )
                      else if (canReroll)
                        TextButton(
                          onPressed: _reroll,
                          child: const Text('换一句'),
                        )
                      else if (profile.growthDays > 0)
                        Text(
                          '今日换句次数已用尽',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.secondary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(quote, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '下一成长节点：$nextCopy',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.secondary),
            ),
            if (profile.growthDays > 0) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              if (profile.name == null)
                _buildNaming(theme)
              else
                Row(
                  children: [
                    Text(
                      '名字：${profile.name}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _rename,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('改名'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNaming(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '给伙伴起个名字',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          maxLength: 8,
          decoration: InputDecoration(
            hintText: '1–8 个中文或英文字符',
            errorText: _nameError,
          ),
          onSubmitted: (_) => _submitName(),
        ),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: _submitName,
          icon: const Icon(Icons.check),
          label: const Text('命名'),
        ),
      ],
    );
  }
}

class _TodayOverview extends StatelessWidget {
  const _TodayOverview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = context.select((AppState s) => s.todayEntries);
    final count = context.select((AppState s) => s.todayCount);
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
            Text('今天还没有沉淀记录',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('在上面记下第一件小事，你的记录图谱会从这里长出来。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.secondary)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日已沉淀 $count 条记录',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...list.take(5).map((e) => _TodayEntryTile(entry: e)),
      ],
    );
  }
}

class _TodayEntryTile extends StatelessWidget {
  const _TodayEntryTile({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = entry.completenessPercent();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$percent%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        title: Text(entry.task,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right,
            color: theme.colorScheme.secondary),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => EvidenceDetailPage(entryId: entry.id))),
      ),
    );
  }
}
