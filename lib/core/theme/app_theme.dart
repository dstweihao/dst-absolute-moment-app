import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 绝对时刻APP — Material 3 主题定义
///
/// 提供明亮（默认）与深色两套。所有圆角取自 [AppRadius]，不硬编码。
/// 颜色取自 [AppPalette]（`AppColors.current` 的同源实例），
/// 保证 ThemeData 与全项目静态引用完全一致。
class AppTheme {
  AppTheme._();

  /// 明亮主题（默认）—— 简洁白底，参照 DeepSeek / 微信
  static ThemeData get lightTheme => _build(AppPalette.light);

  /// 深色主题
  static ThemeData get darkTheme => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final isLight = p.background.computeLuminance() > 0.5;
    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: isLight ? Brightness.light : Brightness.dark,
    ).copyWith(
      surface: p.surface,
      onSurface: p.textPrimary,
      primary: p.primary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,

      // 交互反馈统一收在强调色里。默认值（黑白灰涟漪）在纯平表面上要么
      // 看不见、要么脏，桌面端尤其明显 —— 悬停/聚焦必须给得出可见回执。
      splashColor: p.primary.withValues(alpha: 0.12),
      highlightColor: p.primary.withValues(alpha: 0.06),
      hoverColor: p.primary.withValues(alpha: 0.06),
      focusColor: p.primary.withValues(alpha: 0.12),

      // 让 Material 内置组件与项目自定义排版共用同一套字体栈与字号，
      // 否则它们会退回 Flutter 默认的 Roboto 度量，和旁边的正文对不齐。
      textTheme: AppTypography.textThemeOf(p),

      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.titleOf(p).copyWith(fontSize: 17),
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorders.card,
          side: BorderSide(color: p.border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.inputBackground,
        border: OutlineInputBorder(
          borderRadius: AppBorders.input,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppBorders.input,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppBorders.input,
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppBorders.input,
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppBorders.input,
          borderSide: BorderSide(color: p.danger, width: 2),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        hintStyle: AppTypography.bodyOf(p).copyWith(color: p.textDisabled),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: 0.22),
        selectionHandleColor: p.primary,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surfaceVariant,
          disabledForegroundColor: p.textDisabled,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 14,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppBorders.button),
          textStyle: AppTypography.subtitleOf(p).copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.border),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 14,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppBorders.button),
          textStyle: AppTypography.subtitleOf(p).copyWith(fontSize: 15),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: AppTypography.subtitleOf(p).copyWith(fontSize: 14),
        ),
      ),

      // 底部导航由 shell.dart 自绘（学习居中放大），不用 Material 的
      // NavigationBar —— 因此这里不再需要 navigationBarTheme。

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppBorders.bottomSheet),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.textPrimary,
        contentTextStyle:
            AppTypography.bodyOf(p).copyWith(fontSize: 14, color: p.surface),
        shape: const RoundedRectangleBorder(borderRadius: AppBorders.button),
        behavior: SnackBarBehavior.floating,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: p.primary,
      ),

      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppBorders.card),
        titleTextStyle: AppTypography.subtitleOf(p).copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: AppTypography.bodyOf(p).copyWith(fontSize: 14),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.textPrimary,
          borderRadius: AppBorders.badge,
        ),
        textStyle: AppTypography.captionOf(p).copyWith(color: p.surface),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.progressEmpty,
        thumbColor: p.primary,
      ),
    );
  }
}
