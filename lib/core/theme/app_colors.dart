import 'package:flutter/material.dart';

/// 绝对时刻APP — 语义色板
///
/// [AppPalette] 是一套不可变的语义颜色集合，提供 `light` / `dark` 两套实例。
/// [AppColors] 是全局门面：`AppColors.primary` 等 getter 读取 [AppColors.current]，
/// 让遍布全项目的静态引用无需改成 `Theme.of(context)` 就能随主题切换。
///
/// 切换主题（设置 → 外观）时更新 [AppColors.current] 并以 `ValueKey` 触发整树重建，
/// 见 `lib/app.dart`。默认明亮主题，参照 DeepSeek / 微信的简洁白底风格。
class AppColors {
  AppColors._();

  /// 当前生效色板。默认明亮主题。
  static AppPalette current = AppPalette.light;

  // ---- 主色调 ----
  /// 唯一品牌强调色 — 深青（克制、理性）
  static Color get primary => current.primary;

  /// 叠在 primary 上的前景色（实心按钮里的图标/文字）
  static Color get onPrimary => current.onPrimary;

  /// 语义警示色 — 弱化琥珀（未通过、拦截），**不是**品牌色
  static Color get accent => current.accent;

  /// 成功绿 — 通关、经验、通过
  static Color get success => current.success;

  /// 危险红 — 失败、拦截、物理安全
  static Color get danger => current.danger;

  // ---- 阶段语义色 ----
  //
  // 刻意不用彩虹：七个阶段取自同一族冷色（青 → 石板灰）的深浅阶梯，
  // 阶段之间的区分靠「进度条上的实心/空心/尺寸」而不是靠色相。
  static Color get stageRecall => current.stageRecall; // ⓪ 深板岩
  static Color get stageQuestion => current.stageQuestion; // ① 深青
  static Color get stageBreakdown => current.stageBreakdown; // ② 青
  static Color get stageVerify => current.stageVerify; // ③ 青（渐浅）
  static Color get stageTranslate => current.stageTranslate; // ④ 青（渐浅）
  static Color get stageAction => current.stageAction; // ⑤ 青绿（落地）
  static Color get stageRate => current.stageRate; // ⑥ 石板灰（中性自评）

  /// 根据阶段编号获取语义色
  static Color colorForStage(int stage) => current.colorForStage(stage);

  // ---- 表面/背景色 ----
  static Color get background => current.background;
  static Color get surface => current.surface;
  static Color get surfaceVariant => current.surfaceVariant;
  static Color get inputBackground => current.inputBackground;

  /// 卡片 / 控件描边色
  static Color get border => current.border;

  // ---- 文字色 ----
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textDisabled => current.textDisabled;

  // ---- 进度相关 ----
  static Color get progressEmpty => current.progressEmpty;
  static Color get progressActive => current.progressActive;
  static Color get progressDone => current.progressDone;
  static Color get progressSideQuest => current.progressSideQuest;

  // ---- 难度评级色 ----
  static Color get difficultyTooEasy => current.difficultyTooEasy;
  static Color get difficultySweetSpot => current.difficultySweetSpot;
  static Color get difficultyTooHard => current.difficultyTooHard;
}

/// 一套语义颜色集合。浅色 / 深色各一例。
class AppPalette {
  const AppPalette({
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.success,
    required this.danger,
    required this.stageRecall,
    required this.stageQuestion,
    required this.stageBreakdown,
    required this.stageVerify,
    required this.stageTranslate,
    required this.stageAction,
    required this.stageRate,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.inputBackground,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.progressEmpty,
    required this.progressActive,
    required this.progressDone,
    required this.progressSideQuest,
    required this.difficultyTooEasy,
    required this.difficultySweetSpot,
    required this.difficultyTooHard,
  });

  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color success;
  final Color danger;

  final Color stageRecall;
  final Color stageQuestion;
  final Color stageBreakdown;
  final Color stageVerify;
  final Color stageTranslate;
  final Color stageAction;
  final Color stageRate;

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color inputBackground;
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  final Color progressEmpty;
  final Color progressActive;
  final Color progressDone;
  final Color progressSideQuest;

  final Color difficultyTooEasy;
  final Color difficultySweetSpot;
  final Color difficultyTooHard;

  /// 阶段语义色（下标 0-6）
  List<Color> get stageColors => [
        stageRecall,
        stageQuestion,
        stageBreakdown,
        stageVerify,
        stageTranslate,
        stageAction,
        stageRate,
      ];

  /// 根据阶段编号获取语义色
  Color colorForStage(int stage) => stageColors[stage.clamp(0, 6)];

  /// 明亮主题（默认）—— 克制的白底 + 单一深青强调色
  static const AppPalette light = AppPalette(
    primary: Color(0xFF165DFF),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFFF7D00),
    success: Color(0xFF00B42A),
    danger: Color(0xFFF53F3F),
    stageRecall: Color(0xFF1E3A5F),
    stageQuestion: Color(0xFF165DFF),
    stageBreakdown: Color(0xFF165DFF),
    stageVerify: Color(0xFF0E7C6B),
    stageTranslate: Color(0xFF12897A),
    stageAction: Color(0xFF178F5F),
    stageRate: Color(0xFF475569),
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEEF0F3),
    inputBackground: Color(0xFFF2F4F7),
    border: Color(0xFFE6E8EB),
    textPrimary: Color(0xFF1F2329),
    textSecondary: Color(0xFF6B7280),
    textDisabled: Color(0xFFB0B6C0),
    progressEmpty: Color(0xFFE4E7EC),
    progressActive: Color(0xFF165DFF),
    progressDone: Color(0xFF00B42A),
    progressSideQuest: Color(0xFFB45309),
    difficultyTooEasy: Color(0xFFB45309),
    difficultySweetSpot: Color(0xFF15803D),
    difficultyTooHard: Color(0xFFB91C1C),
  );

  /// 深色主题 —— 同一套语义，换成深底上可读的浅色
  static const AppPalette dark = AppPalette(
    primary: Color(0xFF2DD4BF),
    onPrimary: Color(0xFF06231F),
    accent: Color(0xFFF59E0B),
    success: Color(0xFF4ADE80),
    danger: Color(0xFFF87171),
    stageRecall: Color(0xFF8FB4E0),
    stageQuestion: Color(0xFF5EEAD4),
    stageBreakdown: Color(0xFF2DD4BF),
    stageVerify: Color(0xFF2FBFAC),
    stageTranslate: Color(0xFF34C4B0),
    stageAction: Color(0xFF4ADE80),
    stageRate: Color(0xFF94A3B8),
    background: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    surfaceVariant: Color(0xFF21262D),
    inputBackground: Color(0xFF1C2128),
    // 必须比 surfaceVariant 浅一档：两者同值时，凡「surfaceVariant 底 + 描边」
    // 的组件在暗色下描边会完全隐没。亮色那边靠 textSecondary 天然拉开层次。
    border: Color(0xFF2D333B),
    textPrimary: Color(0xFFE6EDF3),
    textSecondary: Color(0xFF8B949E),
    textDisabled: Color(0xFF484F58),
    progressEmpty: Color(0xFF30363D),
    progressActive: Color(0xFF2DD4BF),
    progressDone: Color(0xFF4ADE80),
    progressSideQuest: Color(0xFFF59E0B),
    difficultyTooEasy: Color(0xFFF59E0B),
    difficultySweetSpot: Color(0xFF4ADE80),
    difficultyTooHard: Color(0xFFF87171),
  );
}
