import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/app_paths.dart';
import '../../data/storage/file_store.dart';
import '../../data/storage/file_store_factory.dart';
import '../../data/storage/folder_picker.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_logo.dart';

/// 首次使用引导
///
/// 两步：① 可选追加个性化资源 → ② 完成。
/// 学习路径只有一个选项（内置的就是那条去个性化的标准路线），
/// 让用户从一项里挑一项是个假选择 —— 直接给，不让他答。
/// 个性化只来自用户自己选定的**个性化资源文件夹**，且是**补充**而非替换
/// （与数据文件夹是两个独立的设置）。全程可跳过，不设门槛。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const int _stepCount = 2;
  static const List<String> _stepTitles = ['个性化资源', '完成'];

  int _step = 0;
  late final TextEditingController _pathController;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 空起点：让用户自己决定，而不是把平台默认目录塞进引导。
    _pathController = TextEditingController();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text('欢迎使用绝对时刻', style: AppTypography.subtitle),
        actions: [
          if (_step < _stepCount - 1)
            TextButton(
              onPressed: _busy ? null : _skipAll,
              child: const Text('跳过'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _stepHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.normal,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _personalizeStep(),
                    _ => _doneStep(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 顶部步骤指示
  // ------------------------------------------------------------------

  Widget _stepHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.sm,
            AppSpacing.pageHorizontal,
            0,
          ),
          child: Row(
            children: List.generate(_stepCount, (i) {
              final reached = i <= _step;
              final done = i < _step;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                      ),
                      child: done
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: AppTypography.label.copyWith(
                                color: reached
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                    ),
                    if (i < _stepCount - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          color: done
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.md,
            AppSpacing.pageHorizontal,
            AppSpacing.sm,
          ),
          child: Text(_stepTitles[_step], style: AppTypography.title),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 步骤① 补充个性化资源（可选）
  // ------------------------------------------------------------------

  Widget _personalizeStep() {
    final custom = ref.watch(supportsCustomFolderProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          '学习路径是内置的通用标准路线，开箱即用，不需要你选。\n'
          '下面是可选的补充：选一个你自己的文件夹，APP 会自动递归扫描，'
          '装下两种东西：\n'
          '· 节点 YAML → 作为「补充关」追加在标准路线末尾，是补充，不是替换；\n'
          '· 笔记、业务背景这类 .md / .txt → 成为每日开课时的「输入源」，'
          '勾选后正文随提问一起发给 AI，拷问就落在你的真实场景上。\n'
          '目录结构不限，放在哪一层都能被找到。',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('个性化资源（可选补充）', style: AppTypography.label),
        const SizedBox(height: AppSpacing.sm),
        if (_canPickFolder()) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _pickFolder,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('选择本地文件夹'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: _pathController,
          enabled: !_busy,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: custom
                ? '也可手动输入，例如 D:\\我的学习路线'
                : '例如 /storage/emulated/0/我的学习路线',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '说明：这个文件夹**只读**，用来补充关卡与输入源，'
          '不要把打卡数据放这里。'
          '打卡记录存在另一个「数据文件夹」里，之后可在设置里指定 —— '
          '放进坚果云同步目录，手机与电脑就能共用同一份数据。',
          style: AppTypography.caption,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          _errorBox(_error!),
        ],
        const SizedBox(height: AppSpacing.xl),
        _primaryButton('下一步', _nextFromPersonalize),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _pathController.clear();
                    _error = null;
                    _step = 1;
                  }),
          child: const Text('跳过，用内置标准路线'),
        ),
      ],
    );
  }

  Widget _errorBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: AppBorders.badge,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(color: AppColors.danger),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 步骤③ 完成
  // ------------------------------------------------------------------

  Widget _doneStep() {
    final folder = _pathController.text.trim();
    final track = TrackCatalog.byId(TrackCatalog.cppId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.xxl,
      ),
      children: [
        const AppLogo(size: 72),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '准备就绪，开始你的确定性通关。',
          textAlign: TextAlign.center,
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Column(
            children: [
              _summaryRow('学习路径', track.title),
              _summaryRow(
                '个性化资源',
                folder.isEmpty ? '无（仅内置标准路线）' : '补充关 + 输入源：$folder',
              ),
              _summaryRow('数据文件夹', '使用默认目录，可在设置里修改'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _primaryButton('开始学习', _finish),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed:
                _busy ? null : () => context.push(AppRouter.aiSettings),
            child: const Text('先配置 AI（可选）'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'AI 是可选增强：不配置也能完成七阶闭环（转为纯自评）。'
          '个性化资源与数据文件夹之后都能在「设置」里随时修改。',
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: AppTypography.label),
          ),
          Expanded(
            child: Text(value, style: AppTypography.body),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 交互
  // ------------------------------------------------------------------

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        ),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: AppTypography.subtitle),
      ),
    );
  }

  Future<void> _nextFromPersonalize() async {
    final folder = _pathController.text.trim();

    // 没选文件夹 → 直接进入完成页，保持默认目录
    if (folder.isEmpty) {
      setState(() => _step = 1);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    // 先探一次确认可读，再切换 —— 让用户在引导里就撞见错误，而不是之后
    try {
      await createFileStore(folder).testConnection();
      await ref.read(learningRootProvider.notifier).changeTo(folder);
    } on FileStoreException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '无法访问该文件夹：$e';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = 1;
    });
  }

  /// 完成引导：写入学习路径 + 标记首次完成 → 进入学习界面。
  Future<void> _finish() async {
    setState(() => _busy = true);

    try {
      await ref.read(configRepositoryProvider).setActiveTrack(TrackCatalog.cppId);
    } catch (_) {
      // 写配置失败不阻塞进入；activeTrackId 已有默认回落
    }
    await ref.read(appSettingsStoreProvider).setFirstRunDone();

    if (!mounted) return;
    context.go(AppRouter.learn);
  }

  /// 顶部「跳过」：直接用默认路径 + 默认目录进入。
  Future<void> _skipAll() async {
    await _finish();
  }

  Future<void> _pickFolder() async {
    final current = _pathController.text.trim();
    final picked = await pickFolder(
      initialDirectory: current.isEmpty ? null : current,
    );
    if (!mounted || picked == null || picked.isEmpty) return;

    _pathController.text = picked;
    setState(() => _error = null);
  }

  bool _canPickFolder() {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }
}
