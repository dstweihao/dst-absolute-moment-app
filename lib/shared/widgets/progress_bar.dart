import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 线性进度条 —— 全 APP 唯一的进度表达方式
///
/// 刻意不做环形圆盘 + 居中大百分比：那种「游戏 HUD」式的仪表盘是最典型的
/// AI 生成感。进度一律用一条安静的横线 + 旁边的数字说清楚。
class LinearProgressBar extends StatelessWidget {
  final double percent;
  final Color? color;
  final double height;

  const LinearProgressBar({
    super.key,
    required this.percent,
    this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (percent / 100).clamp(0, 1)),
        duration: AppDurations.normal,
        curve: Curves.easeOut,
        builder: (context, value, _) {
          return LinearProgressIndicator(
            value: value,
            minHeight: height,
            backgroundColor: AppColors.progressEmpty,
            valueColor: AlwaysStoppedAnimation(
              color ?? AppColors.primary,
            ),
          );
        },
      ),
    );
  }
}
