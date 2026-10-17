import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 沉浸式导航壳
/// 主界面全屏沉浸，通过右上角设置与抽屉呼出辅助功能
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
    );
  }
}
