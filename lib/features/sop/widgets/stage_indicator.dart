import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/enums/app_enums.dart';

/// 七阶段进度指示条
///
/// 三态视觉：已完成实心 ●、当前带光环 ◉、未来空心 ○。
/// 每颗用对应的阶段语义色，让用户对"走到哪了"有一眼可见的感知。
class StageIndicator extends StatelessWidget {
  final SopStageType current;

  /// 已完成的阶段集合（用于回看时正确显示）
  final Set<SopStageType> completed;

  const StageIndicator({
    super.key,
    required this.current,
    this.completed = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          for (final stage in SopStageType.values) ...[
            Expanded(child: _dot(stage)),
            if (stage != SopStageType.values.last)
              Expanded(
                flex: 2,
                child: _connector(stage),
              ),
          ],
        ],
      ),
    );
  }

  Widget _dot(SopStageType stage) {
    final isCurrent = stage == current;
    final isDone = completed.contains(stage) || stage.index < current.index;
    final color = AppColors.colorForStage(stage.index);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppDurations.fast,
          width: isCurrent ? 20 : 14,
          height: isCurrent ? 20 : 14,
          decoration: BoxDecoration(
            color: isDone || isCurrent ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone || isCurrent ? color : AppColors.surfaceVariant,
              width: 2,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: isDone && !isCurrent
              ? const Icon(Icons.check, size: 8, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          _marker(stage),
          style: AppTypography.label.copyWith(
            fontSize: 10,
            color: isCurrent ? color : AppColors.textDisabled,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _connector(SopStageType stage) {
    final done = stage.index < current.index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        height: 2,
        color: done ? AppColors.colorForStage(stage.index) : AppColors.surfaceVariant,
      ),
    );
  }

  static String _marker(SopStageType stage) => switch (stage) {
        SopStageType.recall => '⓪',
        SopStageType.questioning => '①',
        SopStageType.breakdown => '②',
        SopStageType.verification => '③',
        SopStageType.translation => '④',
        SopStageType.actionCard => '⑤',
        SopStageType.selfRating => '⑥',
      };
}
