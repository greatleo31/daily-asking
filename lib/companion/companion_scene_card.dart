import 'package:flutter/material.dart';

import 'companion_profile.dart';

/// 伙伴场景画报卡：动静分层渲染（静态高清背景 + 动态透明 Animated WebP 伙伴）。
///
/// 架构设计：
/// - 底层：高清森林溪畔静态场景（[backgroundAsset]）；
/// - 中层：地面环境柔光接触阴影，锚定伙伴物理站位；
/// - 顶层：透明背景 Animated WebP 伙伴待机循环动图（[characterAsset]）；
/// - 支持紧凑模式（等待卡/通知）与全景模式（伙伴资料弹窗/成长主页）。
class CompanionSceneCard extends StatelessWidget {
  const CompanionSceneCard({
    super.key,
    this.stage,
    this.name,
    this.statusText,
    this.height = 180,
    this.width,
    this.borderRadius = 20,
    this.backgroundAsset = 'assets/companion/bg_river.jpg',
    this.characterAsset = 'assets/companion/sprout_idle.webp',
  });

  /// 伙伴当前成长阶段（可选，提供时在角落展示阶段标签）。
  final CompanionStage? stage;

  /// 伙伴名称（可选）。
  final String? name;

  /// 场景状态文案（如「AI 构思周报中…」或「正在小憩」）。
  final String? statusText;

  /// 卡片高度。
  final double height;

  /// 卡片宽度，为 null 时自适应撑满父容器。
  final double? width;

  /// 圆角半径。
  final double borderRadius;

  /// 静态背景图路径。
  final String backgroundAsset;

  /// 透明动图路径。
  final String characterAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardWidth = width ?? double.infinity;

    return Container(
      width: cardWidth,
      height: height,
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
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // 1. 底层：静态高清背景
          Image.asset(
            backgroundAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.forest_outlined, size: 48),
              ),
            ),
          ),

          // 2. 底部微弱暗角渐变（提升草地质感与文字对比度）
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
          ),

          // 3. 地面柔光阴影（位于草地苔藓接触面）
          Positioned(
            bottom: height * 0.12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: height * 0.48,
                height: height * 0.10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E2D14).withValues(alpha: 0.45),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. 前景：纯透明 Animated WebP 萌宠待机动画
          Positioned(
            bottom: height * 0.10,
            child: SizedBox(
              width: height * 0.62,
              height: height * 0.62,
              child: Image.asset(
                characterAsset,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    stage != null
                        ? Image.asset(stage!.assetPath, fit: BoxFit.contain)
                        : const Icon(Icons.spa, size: 48),
              ),
            ),
          ),

          // 5. 左上角：伙伴标签 / 阶段标签
          if (stage != null || name != null)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

          // 6. 状态覆盖栏（例如 AI 正在生成中…）
          if (statusText != null && statusText!.isNotEmpty)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
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
      ),
    );
  }
}
