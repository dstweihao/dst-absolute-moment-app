import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/storage/file_store.dart';

/// 统一处理 AsyncValue 的三种状态
///
/// 加载态用骨架占位而非转圈，避免页面跳动；
/// 错误态按 [FileStoreException] 分类给出针对性指引。
class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  /// 自定义加载占位。默认是一个定高的骨架块。
  final Widget? loading;

  final VoidCallback? onRetry;

  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.loading,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () =>
          loading ??
          const _SkeletonBlock(height: 100),
      error: (error, stack) => ErrorBox(error: error, onRetry: onRetry),
    );
  }
}

/// 骨架占位块
class _SkeletonBlock extends StatelessWidget {
  final double height;

  const _SkeletonBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppBorders.card,
        border: Border.all(color: AppColors.surfaceVariant),
      ),
    );
  }
}

/// 错误展示框 —— 把异常翻译成人话
class ErrorBox extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry? margin;

  const ErrorBox({
    super.key,
    required this.error,
    this.onRetry,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, title, detail, needsReauth) = _describe(error);

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppBorders.card,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.danger, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.subtitle
                      .copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(detail, style: AppTypography.caption),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(needsReauth ? '重新配置' : '重试'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (IconData, String, String, bool) _describe(Object error) {
    if (error is FileStoreException) {
      return (
        _iconFor(error.kind),
        error.message,
        error.detail,
        error.kind == FileStoreErrorKind.notConfigured,
      );
    }
    return (
      Icons.error_outline,
      '加载失败',
      error.toString(),
      false,
    );
  }

  static IconData _iconFor(FileStoreErrorKind kind) => switch (kind) {
        FileStoreErrorKind.unavailable => Icons.folder_off_outlined,
        FileStoreErrorKind.permissionDenied => Icons.lock_outline,
        FileStoreErrorKind.notConfigured => Icons.settings_outlined,
        FileStoreErrorKind.noSpace => Icons.sd_card_alert_outlined,
        FileStoreErrorKind.readonly => Icons.lock_outline,
        _ => Icons.error_outline,
      };
}

/// 空状态占位
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.subtitle),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 顶部网络错误横幅
///
/// 用横幅而非对话框 —— 不打断用户当前操作。
class NetworkBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const NetworkBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: AppColors.accent.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: AppColors.accent, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption
                  .copyWith(color: AppColors.accent),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}
