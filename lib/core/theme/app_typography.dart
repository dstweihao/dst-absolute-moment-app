import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 绝对时刻APP — 字体栈与字号阶梯
///
/// **中文优先的跨平台字体栈**：拉丁字母与数字走各平台的系统 UI 字体
/// （Windows 的 Segoe UI、Apple 的 SF、Android 的 Roboto），
/// 中文字形则显式回退到平台最合适的黑体 —— 主要是为了避免 Windows 上
/// 掉进宋体（SimSun），那会让小字号的中文发虚、笔画粗细不匀。
///
/// **字距（letterSpacing）**：中文是等宽方块字，小字号下不额外拉开字距
/// 会显得挤；而大号数字相反，需要轻微收紧才不至于松散。这两个方向都在
/// 下面的 `_Spec` 表里按字号分别定死了。
///
/// **表格数字（tabularFigures）**：数字样式统一开启等宽数字，
/// 这样经验值、计数、百分比在跳变时不会左右抖动。
///
/// 颜色取自 [AppColors.current]，随主题切换（无需在调用点传 context）。
/// 注意：因此这些样式**不是 const**，请勿放进 `const` 表达式。
///
/// 另提供 `xxxOf(AppPalette)` 变体：供 [AppTheme] 按指定色板构建
/// TextTheme 用，避免依赖 `AppColors.current` 的赋值时序。
class AppTypography {
  AppTypography._();

  // ------------------------------------------------------------------
  // 字体栈
  // ------------------------------------------------------------------

  /// 拉丁字母 / 数字使用的系统 UI 字体。
  ///
  /// 只有 Windows 需要点名：其余平台的默认字体（SF / Roboto / Cantarell）
  /// 本身就是最优解，硬指定反而会掉进劣化回退。
  static String? get _uiFamily => switch (defaultTargetPlatform) {
        TargetPlatform.windows => 'Segoe UI',
        _ => null,
      };

  /// 中文字形回退链 —— 显式列出，避免系统挑到宋体。
  static List<String> get _cjkFallback => switch (defaultTargetPlatform) {
        TargetPlatform.windows => const [
            'Microsoft YaHei UI',
            'Microsoft YaHei',
            'Segoe UI',
          ],
        TargetPlatform.macOS || TargetPlatform.iOS => const [
            'PingFang SC',
            'Heiti SC',
          ],
        TargetPlatform.android => const [
            'Noto Sans CJK SC',
            'Source Han Sans SC',
          ],
        TargetPlatform.linux || TargetPlatform.fuchsia => const [
            'Noto Sans CJK SC',
            'WenQuanYi Micro Hei',
            'DejaVu Sans',
          ],
      };

  /// 等宽字体。`monospace` 是 Android / Linux 的字体别名，一定能解析；
  /// Windows 与 Apple 必须点名具体字体（原先写死的 `'monospace'`
  /// 在 Windows 上不存在，会静默退回正文字体，等宽区分就丢了）。
  static String get _monoFamily => switch (defaultTargetPlatform) {
        TargetPlatform.windows => 'Consolas',
        TargetPlatform.macOS || TargetPlatform.iOS => 'SF Mono',
        _ => 'monospace',
      };

  static List<String> get _monoFallback => switch (defaultTargetPlatform) {
        TargetPlatform.windows => const ['Cascadia Mono', 'Courier New'],
        TargetPlatform.macOS || TargetPlatform.iOS => const ['Menlo', 'Courier'],
        _ => const ['Roboto Mono', 'Droid Sans Mono', 'DejaVu Sans Mono'],
      };

  /// 等宽数字：让计数在变化时保持定宽，不左右跳动。
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // ------------------------------------------------------------------
  // 字号阶梯
  // ------------------------------------------------------------------

  static const _Spec _display = _Spec(
    size: 32,
    weight: FontWeight.bold,
    height: 1.2,
    tracking: -0.5,
    tabular: true,
  );

  static const _Spec _title = _Spec(
    size: 20,
    weight: FontWeight.w600,
    height: 1.3,
    tracking: 0.2,
  );

  static const _Spec _subtitle = _Spec(
    size: 16,
    weight: FontWeight.w500,
    height: 1.4,
    tracking: 0.2,
  );

  static const _Spec _body = _Spec(
    size: 15,
    weight: FontWeight.normal,
    height: 1.6,
    tracking: 0.3,
  );

  static const _Spec _bodyMuted = _Spec(
    size: 15,
    weight: FontWeight.normal,
    height: 1.6,
    tracking: 0.3,
    muted: true,
  );

  static const _Spec _caption = _Spec(
    size: 13,
    weight: FontWeight.normal,
    height: 1.6,
    tracking: 0.3,
    muted: true,
  );

  static const _Spec _label = _Spec(
    size: 12,
    weight: FontWeight.w500,
    height: 1.4,
    tracking: 0.4,
    muted: true,
  );

  static const _Spec _mono = _Spec(
    size: 15,
    weight: FontWeight.w500,
    height: 1.5,
    tracking: 0.4,
    tabular: true,
    mono: true,
  );

  static const _Spec _monoSmall = _Spec(
    size: 14,
    weight: FontWeight.w600,
    height: 1.4,
    tracking: 0.3,
    tabular: true,
    mono: true,
  );

  // ------------------------------------------------------------------
  // 对外样式（读 AppColors.current）
  // ------------------------------------------------------------------

  /// Display — 32/Bold，用于难度分数、百分比等大数字
  static TextStyle get display => displayOf(AppColors.current);

  /// Title — 20/SemiBold，用于页面标题、节点名
  static TextStyle get title => titleOf(AppColors.current);

  /// Subtitle — 16/Medium，用于卡片标题
  static TextStyle get subtitle => subtitleOf(AppColors.current);

  /// Body — 15/Regular，用于正文与输入内容
  static TextStyle get body => bodyOf(AppColors.current);

  /// BodyMuted — 15/Regular，次要正文
  static TextStyle get bodyMuted => bodyMutedOf(AppColors.current);

  /// Caption — 13/Regular。辅助说明多为多行中文，行高给足
  static TextStyle get caption => captionOf(AppColors.current);

  /// Label — 12/Medium。小字号要靠更大字距才立得住
  static TextStyle get label => labelOf(AppColors.current);

  /// Mono — 等宽，用于英文术语、代码片段。
  ///
  /// 术语解释铁律要求英文词旁必须加中文解释，英文词本身用等宽，
  /// 好在视觉上与中文正文区分开。
  static TextStyle get mono => monoOf(AppColors.current);

  /// MonoSmall — 小号等宽，用于术语标记
  static TextStyle get monoSmall => monoSmallOf(AppColors.current);

  // ------------------------------------------------------------------
  // 按指定色板构建（供 AppTheme 用，不依赖 AppColors.current）
  // ------------------------------------------------------------------

  static TextStyle displayOf(AppPalette p) => _make(p, _display);
  static TextStyle titleOf(AppPalette p) => _make(p, _title);
  static TextStyle subtitleOf(AppPalette p) => _make(p, _subtitle);
  static TextStyle bodyOf(AppPalette p) => _make(p, _body);
  static TextStyle bodyMutedOf(AppPalette p) => _make(p, _bodyMuted);
  static TextStyle captionOf(AppPalette p) => _make(p, _caption);
  static TextStyle labelOf(AppPalette p) => _make(p, _label);
  static TextStyle monoOf(AppPalette p) => _make(p, _mono);
  static TextStyle monoSmallOf(AppPalette p) => _make(p, _monoSmall);

  /// 完整 [TextTheme] —— 让 Material 内置组件（ListTile、NavigationBar、
  /// Dialog、TextField、SnackBar…）和项目自定义排版共用同一套字体栈与字号，
  /// 否则它们会退回 Flutter 默认的 Roboto 度量，与旁边的正文对不齐。
  static TextTheme textThemeOf(AppPalette p) => TextTheme(
        displayLarge: displayOf(p),
        displayMedium: displayOf(p),
        displaySmall: displayOf(p).copyWith(fontSize: 26),

        headlineLarge: titleOf(p).copyWith(fontSize: 24),
        headlineMedium: titleOf(p),
        headlineSmall: titleOf(p).copyWith(fontSize: 18),

        titleLarge: titleOf(p),
        titleMedium: subtitleOf(p),
        titleSmall: subtitleOf(p).copyWith(fontSize: 14),

        bodyLarge: bodyOf(p),
        bodyMedium: bodyOf(p).copyWith(fontSize: 14),
        bodySmall: captionOf(p),

        // 按钮等强调文字走 Medium，比正文重、比标题轻
        labelLarge: subtitleOf(p).copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: labelOf(p),
        labelSmall: labelOf(p).copyWith(fontSize: 11),
      );

  // ------------------------------------------------------------------

  static TextStyle _make(AppPalette p, _Spec s) {
    final mono = s.mono;
    return TextStyle(
      fontFamily: mono ? _monoFamily : _uiFamily,
      fontFamilyFallback: mono ? _monoFallback : _cjkFallback,
      fontSize: s.size,
      fontWeight: s.weight,
      height: s.height,
      letterSpacing: s.tracking,
      fontFeatures: s.tabular ? _tabular : null,
      color: s.muted ? p.textSecondary : p.textPrimary,
    );
  }
}

/// 单条字号规格 —— 让「对外样式」与「按色板构建」两条路径共用同一份定义，
/// 避免两边漂移。
class _Spec {
  final double size;
  final FontWeight weight;
  final double height;
  final double tracking;

  /// 用次要文字色（textSecondary）
  final bool muted;

  /// 启用等宽数字
  final bool tabular;

  /// 用等宽字体栈
  final bool mono;

  const _Spec({
    required this.size,
    required this.weight,
    required this.height,
    required this.tracking,
    this.muted = false,
    this.tabular = false,
    this.mono = false,
  });
}
