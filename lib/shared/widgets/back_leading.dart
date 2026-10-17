import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 次级页面的返回按钮。
///
/// 为什么不直接用 [AppBar] 的自动返回箭头：自动箭头只在
/// `canPop()` 为真时出现。而这些页面既可以是被 push 进来的（有栈可退），
/// 也可能是深链或 `go()` 直接落地的（无栈可退）——后一种情况下
/// 顶部会**一个返回入口都没有**，用户就被困在页面里了。
///
/// 所以这里显式渲染按钮：能退就退，退不了就回落到 [fallback]，
/// 保证任何进入方式下都有一条出路。
class PageBackButton extends StatelessWidget {
  const PageBackButton({
    super.key,
    required this.fallback,
    this.tooltip = '返回',
  });

  /// 无栈可退时落到哪个路由（通常是 `/learn` 或父级列表）。
  final String fallback;

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallback);
        }
      },
    );
  }
}
