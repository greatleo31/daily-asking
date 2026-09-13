/// 伙伴场景画报卡：整幅展示伙伴待机动画（素材自带水岸草地场景）。
///
/// 与全屏生成等待蒙层共用同一份动图 [companionIdleSceneAsset]，因此不再做
/// 「静态高清背景 + 透明角色动图」分层，也不需要地面接触阴影与暗角渐变。
/// 素材为 1:1 不透明动图：默认按正方形呈现（整幅可见）；显式传入 [height]
/// 时按该高度裁切填充。只接收不可变快照（[CompanionStage]），不直接读
/// Repository。
library;

import 'package:flutter/material.dart';

import 'companion_profile.dart';

class CompanionSceneCard extends StatelessWidget {
  const CompanionSceneCard({
    super.key,
    this.stage,
    this.name,
    this.statusText,
    this.showSpinner = false,
    this.height,
    this.width,
    this.borderRadius = 20,
  });

  /// 伙伴当前成长阶段（可选，提供时在角落展示阶段标签）。
  final CompanionStage? stage;

  /// 伙伴名称（可选）。
  final String? name;

  /// 场景状态文案（如「正在生成「周报」…」或「正在小憩」）。
  final String? statusText;

  /// 状态栏是否展示微型旋转指示器。
  final bool showSpinner;

  /// 卡片固定高度；为 null 时按素材比例呈现为正方形。
  final double? height;

  /// 卡片宽度，为 null 时自适应撑满父容器。
  final double? width;

  /// 圆角半径。
  final double borderRadius;

  /// 伙伴待机动画素材（自带完整场景的循环动图）。
  static const String sceneAsset = companionIdleSceneAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardWidth = width ?? double.infinity;

    final Widget scene = Image.asset(
      companionIdleSceneAsset,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => stage != null
          ? Image.asset(stage!.assetPath, fit: BoxFit.cover)
          : Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.forest_outlined, size: 48),
              ),
            ),
    );

    final Widget body = Stack(
      fit: StackFit.expand,
      children: [
        // 1. 整幅伙伴待机动画（自带场景）
        scene,

        // 2. 左上角：伙伴标签 / 阶段标签
        if (stage != null || name != null)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stage != null) ...[
                    Text(
                      stage!.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF2E6B38),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (name != null) const SizedBox(width: 4),
                  ],
                  if (name != null)
                    Text(
                      name!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),

        // 3. 右上角：状态覆盖栏（例如 AI 正在生成中…）
        if (statusText != null && statusText!.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSpinner) ...[
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    statusText!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    final Widget framed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: body,
      ),
    );

    return SizedBox(
      width: cardWidth,
      height: height,
      child: height == null
          ? AspectRatio(aspectRatio: 1, child: framed)
          : framed,
    );
  }
}
