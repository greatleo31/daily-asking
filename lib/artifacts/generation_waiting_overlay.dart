/// 全屏等待蒙层：生成产物期间铺满全屏展示伙伴等待动画。
///
/// 交互约定：
/// - 伙伴等待动画（`bloom_idle.webp`：116 帧，约 5.08s）完整播放一遍后，
///   底部提示才缓慢淡入；提示出现前，点击空白处与系统返回均不响应；
/// - 提示出现后点击空白处（或按系统返回）关闭蒙层，回到工作室底层的内嵌画报大卡片；
/// - 用户未关闭蒙层时，由页面在生成完成后收起蒙层并平滑切到 Markdown 产物页。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../companion/companion_profile.dart';
import '../core/models.dart';

/// 伙伴等待动画的完整循环时长（`bloom_idle.webp`：116 帧，共 5080ms）。
const Duration kCompanionSceneLoop = Duration(milliseconds: 5080);

/// 底部提示「慢慢显示」的淡入时长。
const Duration kWaitingHintFadeIn = Duration(milliseconds: 900);

class GenerationWaitingOverlay extends StatefulWidget {
  const GenerationWaitingOverlay({
    super.key,
    required this.type,
    this.stage,
    this.name,
    this.onDismiss,
  });

  /// 正在生成的产物类型，用于状态文案。
  final ArtifactType type;

  /// 伙伴当前成长阶段（可选，展示在状态栏）。
  final CompanionStage? stage;

  /// 伙伴名称（可选）。
  final String? name;

  /// 用户在提示出现后关闭蒙层时回调（蒙层随后自行退出）。
  final VoidCallback? onDismiss;

  /// 首遍播放结束后的关闭提示文案。
  static const String dismissHint = '点击空白处关闭';

  /// 蒙层未关闭时的完成行为说明。
  static const String autoOpenHint = '生成完成后会自动打开产物';

  /// 蒙层等待动画：自带完整场景（水岸草地 + 伙伴），等比完整呈现。
  /// 与工作室画报大卡片共用同一常量，避免两处各写一遍路径。
  static const String sceneAsset = companionIdleSceneAsset;

  /// 由等待动画首帧派生的模糊压暗幕布，用于铺满整屏、避免方形两侧留白。
  static const String sceneBackdropAsset = companionIdleSceneBackdropAsset;

  @override
  State<GenerationWaitingOverlay> createState() =>
      _GenerationWaitingOverlayState();
}

class _GenerationWaitingOverlayState extends State<GenerationWaitingOverlay> {
  Timer? _hintTimer;
  bool _hintVisible = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // 首遍动画播完后才放出关闭提示，避免用户在第一遍播放中误触离开。
    _hintTimer = Timer(kCompanionSceneLoop, () {
      if (mounted) setState(() => _hintVisible = true);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _requestDismiss() {
    if (!_hintVisible || _closing) return;
    _closing = true;
    widget.onDismiss?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return PopScope(
      // 关闭提示出现前拦住系统返回，行为与「点击空白处」保持一致。
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestDismiss();
      },
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _requestDismiss,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. 底层：等待动画首帧派生的模糊幕布，铺满整屏并提供环境光
              Image.asset(
                GenerationWaitingOverlay.sceneBackdropAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
              ),

              // 2. 压暗蒙层：保证文案可读，同时把注意力锚在动画主体上
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Color(0x33000000),
                      Color(0x77000000),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),

              // 3. 视觉主体：整幅等待动画（等比完整呈现，纵向最多占七成屏高）
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: size.width - 32,
                    maxHeight: size.height * 0.7,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x73000000),
                            blurRadius: 32,
                            spreadRadius: 2,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          GenerationWaitingOverlay.sceneAsset,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) =>
                              widget.stage != null
                              ? Image.asset(
                                  widget.stage!.assetPath,
                                  fit: BoxFit.contain,
                                )
                              : const Icon(
                                  Icons.spa,
                                  size: 64,
                                  color: Colors.white24,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. 顶部：伙伴标签与生成状态
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.name != null && widget.name!.isNotEmpty) ...[
                          Text(
                            widget.name!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              shadows: const [
                                Shadow(color: Color(0x99000000), blurRadius: 8),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '正在生成「${widget.type.label}」…',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. 底部：首遍播放结束后淡入的关闭提示
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 40,
                    ),
                    child: AnimatedOpacity(
                      opacity: _hintVisible ? 1 : 0,
                      duration: kWaitingHintFadeIn,
                      curve: Curves.easeIn,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.touch_app_outlined,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  GenerationWaitingOverlay.dismissHint,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            GenerationWaitingOverlay.autoOpenHint,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
