import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers.dart';
import 'router.dart';

/// 应用根 Widget
///
/// 最小可执行方案：Web 端或首次完成后直达学习主界面，聚焦核心标准路线。
class AbsoluteMomentApp extends ConsumerStatefulWidget {
  /// 是否已完成首次引导；决定启动落点是引导页还是学习界面。
  final bool initialFirstRunDone;

  const AbsoluteMomentApp({super.key, this.initialFirstRunDone = true});

  @override
  ConsumerState<AbsoluteMomentApp> createState() => _AbsoluteMomentAppState();
}

class _AbsoluteMomentAppState extends ConsumerState<AbsoluteMomentApp> {
  /// 只构建一次：GoRouter 每次 build 新建会丢掉导航栈
  late final GoRouter _router = AppRouter.build(
    initialLocation: (kIsWeb || widget.initialFirstRunDone)
        ? AppRouter.learn
        : AppRouter.onboarding,
  );

  @override
  void initState() {
    super.initState();
    // 启动后静默查一次新版本：结果只进常驻 notifier，不弹窗、不阻断启动，
    // 设置页据此决定要不要亮「有新版本」。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(updateStatusProvider.notifier).check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);

    // 解析为具体明暗（跟随系统时取系统亮度）
    final brightness = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context),
    };
    final dark = brightness == Brightness.dark;

    // 同步给全局静态色板。用 key 强制重建，让所有静态引用的颜色重新求值。
    AppColors.current = dark ? AppPalette.dark : AppPalette.light;

    return MaterialApp.router(
      key: ValueKey(dark),
      title: '绝对时刻',
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
