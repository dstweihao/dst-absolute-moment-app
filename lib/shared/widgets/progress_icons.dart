import 'package:flutter/material.dart';

/// 进度相关的图标映射
///
/// 领域层 [PlayerProgress] 只出数字与文字，图标属于表现层，放在这里统一收口。
/// 刻意全部使用中性的 Material 几何图标 —— 不用 emoji，不用卡通形象。
class ProgressIcons {
  ProgressIcons._();

  /// 阶段图标（1-5）—— 每关只有一个主题，图标就是那件事本身
  static IconData forPhase(int phase) => switch (phase) {
        1 => Icons.terminal, // C++ 基础
        2 => Icons.memory, // C++ 语言核心
        3 => Icons.hub_outlined, // 并发编程
        4 => Icons.build_circle_outlined, // 工程实践
        5 => Icons.settings_suggest_outlined, // 系统编程
        _ => Icons.crop_square,
      };

  /// 阶段收官节点
  static const IconData closing = Icons.flag_outlined;

  /// 综合实战 / 补充关之类不占主线的关卡
  static const IconData elective = Icons.bookmark_border;

  /// 已通过
  static const IconData passed = Icons.check;

  /// 未解锁
  static const IconData locked = Icons.lock_outline;

  /// 段位图标（层级 1-6）
  static IconData forRankTier(int tier) => switch (tier) {
        >= 6 => Icons.workspace_premium,
        5 => Icons.diamond_outlined,
        4 => Icons.military_tech_outlined,
        3 => Icons.star_outline,
        2 => Icons.shield_outlined,
        _ => Icons.circle_outlined,
      };
}
