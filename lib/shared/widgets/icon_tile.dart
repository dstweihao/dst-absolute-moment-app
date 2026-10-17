import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// 图标方块 —— 全 APP 反复出现的「圆角方块 + 语义色浅底」母题
///
/// 段位图标、阶段标记、关卡数字、拆塔官头像都是它。以前每个页面各自
/// 手写 `Container` + `BoxDecoration`，同一个 44px 方块在不同文件里
/// 圆角 8 / 12 并存、底色浓度 0.08 / 0.10 / 0.12 / 0.15 各写各的。
/// 收在这里之后，圆角与浓度只有一处定义。
///
/// [color] 只决定色调，深浅交给 [fillAlpha]；
/// [borderAlpha] 为 null 时无描边，给了才描 —— 描边是例外，不是默认。
class IconTile extends StatelessWidget {
  final Color color;
  final Widget child;

  /// 边长。同一个母题按信息权重选 40 / 44 / 48 / 52 / 56。
  final double size;

  /// 底色浓度
  final double fillAlpha;

  /// 描边浓度；null = 不描边
  final double? borderAlpha;

  const IconTile({
    super.key,
    required this.color,
    required this.child,
    this.size = 44,
    this.fillAlpha = 0.10,
    this.borderAlpha,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderAlpha;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: fillAlpha),
        borderRadius: AppBorders.tile,
        border: border == null
            ? null
            : Border.all(color: color.withValues(alpha: border)),
      ),
      child: child,
    );
  }
}
