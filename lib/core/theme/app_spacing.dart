import 'package:flutter/widgets.dart';

/// 绝对时刻APP — 间距与圆角常量
///
/// 4pt 基准栅格。所有布局间距必须取自此处，禁止硬编码魔法数字。
class AppSpacing {
  AppSpacing._();

  // ---- 间距 ----
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// 页面水平边距
  static const double pageHorizontal = 16;

  /// 卡片内边距
  static const double cardPadding = 16;

  /// 卡片之间的垂直间距
  static const double cardGap = 12;

  /// 列表项之间的间距
  static const double listGap = 8;

  /// 底部导航栏预留高度（用于列表底部留白）
  static const double bottomNavClearance = 80;
}

/// 圆角常量
class AppRadius {
  AppRadius._();

  /// 卡片
  static const double card = 14;

  /// 图标方块（等级图标、阶段标记、关卡数字）—— 全 APP 统一走 [IconTile]
  static const double tile = 12;

  /// 按钮
  static const double button = 8;

  /// 输入框
  static const double input = 8;

  /// 徽章 / 标签
  static const double badge = 6;

  /// 微小元素（区块竖条、迷你图条、进度裁剪）—— 比徽章更收，几乎方正
  static const double small = 4;

  /// 底部弹窗
  static const double bottomSheet = 20;

  /// 圆形（头像、进度点）
  static const double circle = 999;
}

/// 常用 BorderRadius 快捷方式
class AppBorders {
  AppBorders._();

  static const card = BorderRadius.all(Radius.circular(AppRadius.card));
  static const tile = BorderRadius.all(Radius.circular(AppRadius.tile));
  static const button = BorderRadius.all(Radius.circular(AppRadius.button));
  static const input = BorderRadius.all(Radius.circular(AppRadius.input));
  static const badge = BorderRadius.all(Radius.circular(AppRadius.badge));
  static const small = BorderRadius.all(Radius.circular(AppRadius.small));
  static const bottomSheet =
      BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet));
}

/// 动画时长常量
class AppDurations {
  AppDurations._();

  /// 快速反馈（按钮按下、勾选）
  static const Duration fast = Duration(milliseconds: 150);

  /// 常规过渡（页面切换、卡片展开）
  static const Duration normal = Duration(milliseconds: 300);

  /// 慢速（进度环填充、阶段切换）
  static const Duration slow = Duration(milliseconds: 600);
}
