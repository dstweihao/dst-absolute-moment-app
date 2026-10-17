import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/update_info.dart';
import '../../domain/models/update_status.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/back_leading.dart';
import '../../shared/widgets/progress_bar.dart';
import '../../shared/widgets/section_header.dart';

/// 版本更新页
///
/// 检查是「问一句」，更新是「做一件事」—— 所以状态卡只有一处按钮，
/// 按钮文案随平台变：桌面能自己下载安装，其余平台只能把人送到下载页。
class UpdatePage extends ConsumerStatefulWidget {
  const UpdatePage({super.key});

  @override
  ConsumerState<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends ConsumerState<UpdatePage> {
  bool _installing = false;
  double? _progress;
  String? _note;
  bool _noteIsError = false;

  /// 只有桌面端能把安装包落到本机并拉起 —— 其余平台一律走浏览器
  bool get _canInstallInApp {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const PageBackButton(fallback: AppRouter.storageSettings),
        title: const Text('版本更新'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          _versionCard(),
          const SizedBox(height: AppSpacing.cardGap),
          _statusCard(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------

  Widget _versionCard() {
    final version = ref.watch(appVersionProvider).value ?? '读取中…';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update_alt,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('当前版本', style: AppTypography.subtitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(version, style: AppTypography.monoSmall),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final status = ref.watch(updateStatusProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('更新状态', style: AppTypography.subtitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ..._statusBody(status),
          if (_note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _noteBox(_note!, _noteIsError ? AppColors.danger : AppColors.success),
          ],
        ],
      ),
    );
  }

  List<Widget> _statusBody(UpdateStatus status) {
    switch (status) {
      case UpdateIdle():
        return [
          Text('尚未检查过更新。', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          _checkButton(),
        ];

      case UpdateChecking():
        return [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('正在检查…', style: AppTypography.caption),
            ],
          ),
        ];

      case UpdateUpToDate(:final currentVersion, :final latestVersion):
        return [
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('已是最新版本', style: AppTypography.body),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            latestVersion == null
                ? '当前 $currentVersion，仓库暂无正式发布。'
                : '当前 $currentVersion，仓库最新 $latestVersion。',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          _checkButton(label: '再查一次'),
        ];

      case UpdateAvailable(:final currentVersion, :final release):
        return [
          Row(
            children: [
              TagBadge(text: '新版本 ${release.tagName}',
                  color: AppColors.primary),
              const Spacer(),
              Text('当前 $currentVersion', style: AppTypography.caption),
            ],
          ),
          if (release.notes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _notesBox(release.notes.trim()),
          ],
          if (_installing) ...[
            const SizedBox(height: AppSpacing.md),
            _progressBar(),
          ],
          const SizedBox(height: AppSpacing.md),
          _actionButtons(release),
        ];

      case UpdateCheckFailed(:final message):
        return [
          _noteBox(message, AppColors.danger),
          const SizedBox(height: AppSpacing.md),
          _checkButton(label: '重试'),
        ];
    }
  }

  Widget _checkButton({String label = '检查更新'}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _installing
            ? null
            : () {
                setState(() => _note = null);
                ref.read(updateStatusProvider.notifier).check();
              },
        child: Text(label),
      ),
    );
  }

  Widget _actionButtons(ReleaseInfo release) {
    if (!_canInstallInApp) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _installing ? null : () => _openPage(release.htmlUrl),
          child: const Text('前往下载页'),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: _installing ? null : () => _install(release),
            child: Text(_installing ? '正在下载…' : '下载并更新'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: _installing ? null : () => _openPage(release.htmlUrl),
          child: const Text('前往下载页'),
        ),
      ],
    );
  }

  Widget _progressBar() {
    final progress = _progress;
    if (progress == null) {
      return ClipRRect(
        borderRadius: AppBorders.small,
        child: LinearProgressIndicator(
          minHeight: 6,
          backgroundColor: AppColors.progressEmpty,
          valueColor: AlwaysStoppedAnimation(AppColors.primary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressBar(percent: progress * 100),
        const SizedBox(height: AppSpacing.xs),
        Text('已下载 ${(progress * 100).toStringAsFixed(0)}%',
            style: AppTypography.caption),
      ],
    );
  }

  Widget _notesBox(String notes) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: AppBorders.badge,
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: SelectableText(notes, style: AppTypography.caption),
      ),
    );
  }

  Widget _noteBox(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppBorders.badge,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: AppTypography.caption.copyWith(color: color)),
    );
  }

  // ------------------------------------------------------------------

  Future<void> _install(ReleaseInfo release) async {
    setState(() {
      _installing = true;
      _progress = null;
      _note = null;
    });

    final result = await ref.read(updateInstallerProvider)(
      release,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;
    setState(() {
      _installing = false;
      _noteIsError = !result.isSuccess;
      _note = result.isSuccess
          ? switch (result.outcome) {
              InstallOutcome.launched =>
                '已启动安装程序，按提示完成后请重启应用',
              InstallOutcome.openedInBrowser =>
                '已打开下载页面，请在浏览器中下载安装',
              InstallOutcome.failed => '',
            }
          : result.message;
    });
  }

  Future<void> _openPage(String htmlUrl) async {
    setState(() {
      _installing = true;
      _note = null;
    });

    final result = await ref.read(openReleasePageProvider)(htmlUrl);

    if (!mounted) return;
    setState(() {
      _installing = false;
      _noteIsError = !result.isSuccess;
      _note = result.isSuccess ? '已打开下载页面' : result.message;
    });
  }
}
