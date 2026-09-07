/// 伙伴头像共享组件：今日页与工作室等待卡复用同一素材与动画外观。
///
/// 行为：
/// - [CompanionAvatarMode.oneShot]：阶段素材整图切换用轻量淡入淡出；
///   每次 [stretchTrigger] 递增播放一次低幅度舒展（约 1.00→1.04→1.00）。
/// - [CompanionAvatarMode.loop]：低幅度循环缩放（1.00→1.03→1.00，约 1400ms 无缝）；
///   供生成等待等场景陪伴展示。
/// - `MediaQuery.disableAnimations` 启用时一律直接展示当前阶段静态素材，不播放动画。
/// 只接收不可变快照（[CompanionStage]），不直接读 Repository。
library;

import 'package:flutter/material.dart';

import 'companion_profile.dart';

enum CompanionAvatarMode { oneShot, loop }

class CompanionAvatar extends StatefulWidget {
  const CompanionAvatar({
    super.key,
    required this.stage,
    this.mode = CompanionAvatarMode.oneShot,
    this.stretchTrigger = 0,
    this.size = 112,
  });

  /// 当前视觉阶段（含素材路径）。
  final CompanionStage stage;

  /// oneShot：随 [stretchTrigger] 递增播放舒展；loop：持续循环缩放。
  final CompanionAvatarMode mode;

  /// oneShot 模式的舒展触发计数（与今日页保存成功计数挂钩）。
  final int stretchTrigger;

  /// 头像素材边长（默认与今日页一致 112）。
  final double size;

  @override
  State<CompanionAvatar> createState() => _CompanionAvatarState();
}

class _CompanionAvatarState extends State<CompanionAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 一次舒展（oneShot）：1.00 → 1.04 → 1.00，520ms。
  late final Animation<double> _stretch;

  /// 循环呼吸（loop）：1.00 → 1.03 → 1.00，约 1400ms 无缝往返。
  late final Animation<double> _breath;

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
    _breath = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.03)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.03, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _syncLoop() {
    _controller.stop();
    if (widget.mode == CompanionAvatarMode.loop && !_reduceMotion) {
      _controller.duration = const Duration(milliseconds: 1400);
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CompanionAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final modeChanged = widget.mode != oldWidget.mode;
    if (widget.mode == CompanionAvatarMode.oneShot) {
      if (modeChanged) {
        // 离开 loop 时复位动画曲线，回到静止待命状态（尊重减少动态）。
        _controller.stop();
        _controller.value = _reduceMotion ? 1.0 : 0.0;
      }
      if (widget.stretchTrigger != oldWidget.stretchTrigger) {
        if (_reduceMotion) {
          _controller.value = 1.0; // 减少动态：直接展示最终图
        } else {
          _controller.forward(from: 0);
        }
      }
    } else if (modeChanged) {
      _controller.duration = const Duration(milliseconds: 1400);
      _controller.value = 0.0;
      _syncLoop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _reduceMotion;
    final animation = widget.mode == CompanionAvatarMode.loop && !reduceMotion
        ? _breath
        : _stretch;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ScaleTransition(
        scale: animation,
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
    );
  }
}
