import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 统一样式的卡片容器
///
/// 全 APP 的卡片都走这里，保证圆角、内边距、描边一致。
/// 明亮主题下白底 + 细描边、无阴影，贴近 DeepSeek / 微信的简洁观感。
/// [accentColor] 用于给特定卡片加语义色描边（如今日关卡、阶段色）。
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? accentColor;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.accentColor,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor;
    final decoration = BoxDecoration(
      color: backgroundColor ?? AppColors.surface,
      borderRadius: AppBorders.card,
      border: Border.all(
        color: accent?.withValues(alpha: 0.55) ?? AppColors.border,
      ),
    );
    final inset = padding ?? const EdgeInsets.all(AppSpacing.cardPadding);
    final tap = onTap;

    if (tap == null) {
      return Container(padding: inset, decoration: decoration, child: child);
    }

    // 底色必须画在 InkWell **下面**（Ink 而非 Container），否则不透明的
    // Container 会把涟漪和悬停高亮整个盖住 —— 桌面端点了跟没点一样。
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: tap,
          borderRadius: AppBorders.card,
          child: Padding(padding: inset, child: child),
        ),
      ),
    );
  }
}
