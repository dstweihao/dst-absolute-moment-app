import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// 区块标题 —— 常用于分组列表
class SectionHeader extends StatelessWidget {
  final String title;

  /// 右侧的补充说明，如 `3/15 节点`
  final String? trailing;

  /// 左侧的语义色竖条，用于阶段分组
  final Color? accentColor;

  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.accentColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    // 提到局部变量以获得类型提升（公有字段无法直接提升）
    final trailingText = trailing;
    final accent = accentColor;

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (accent != null) ...[
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: AppBorders.small,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(title, style: AppTypography.subtitle),
          ),
          if (trailingText != null)
            Text(trailingText, style: AppTypography.caption),
          ?action,
        ],
      ),
    );
  }
}

/// 标签徽章
///
/// 命名为 TagBadge 而非 Badge —— 后者与 Flutter Material 内置的
/// `Badge` 冲突，会导致 import 歧义。
///
/// 默认是**中性**的：浅灰底 + 次级文字色。只有确实表达状态（已通过 / 今日）
/// 时才由调用方传入语义色 —— 满屏彩色胶囊是最典型的「AI 生成感」。
class TagBadge extends StatelessWidget {
  final String text;

  /// 语义色。不传 = 中性标签。
  final Color? color;

  const TagBadge({
    super.key,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: c == null
            ? AppColors.surfaceVariant
            : c.withValues(alpha: 0.12),
        borderRadius: AppBorders.badge,
      ),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: c ?? AppColors.textSecondary,
          fontWeight: c == null ? FontWeight.w500 : FontWeight.w600,
        ),
      ),
    );
  }
}

/// 键值行 —— 详情页的元信息展示
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
