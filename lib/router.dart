import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/ai_settings/ai_settings_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/learn/learn_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/settings/storage_settings_page.dart';
import 'features/settings/update_page.dart';
import 'features/sop/sop_setup_page.dart';
import 'features/sop/sop_session_page.dart';
import 'features/stats/stats_page.dart';
import 'features/tracks/node_detail_page.dart';
import 'features/tracks/nodes_page.dart';
import 'features/tracks/tracks_page.dart';
import 'shell.dart';

/// 全局路由表
///
/// 首屏是**学习界面**（`/learn`）—— 打开就能开始对话，
/// 没有引导页、没有连接检查。配置都在 `/settings/*` 里，按需进入。
///
/// 采用 StatefulShellRoute 实现底部导航，每个标签保留各自的导航栈。
class AppRouter {
  AppRouter._();

  static const String onboarding = '/onboarding';
  static const String learn = '/learn';
  static const String dashboard = '/dashboard';
  static const String tracks = '/tracks';
  static const String stats = '/stats';
  static const String aiSettings = '/settings/ai';
  static const String storageSettings = '/settings/storage';
  static const String update = '/settings/update';
  static const String sopSetup = '/sop/setup';
  static const String sopSession = '/sop/session';

  static String nodesOf(String trackId) => '/tracks/$trackId';
  static String nodeDetail(String trackId, String nodeId) =>
      '/tracks/$trackId/nodes/$nodeId';

  static final GlobalKey<NavigatorState> _rootKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static GoRouter build({String initialLocation = learn}) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: initialLocation,
      routes: [
        // 首次引导页（可选配置）
        GoRoute(
          path: onboarding,
          builder: (context, state) => const OnboardingPage(),
        ),

        // SOP 会话 —— 全屏沉浸式，刻意不带底部导航
        GoRoute(
          path: sopSetup,
          builder: (context, state) => const SopSetupPage(),
        ),
        GoRoute(
          path: sopSession,
          builder: (context, state) => const SopSessionPage(),
        ),

        // AI 配置 —— 全屏，从学习页 / 统计页 / 引导页进入
        GoRoute(
          path: aiSettings,
          builder: (context, state) => const AiSettingsPage(),
        ),

        // 版本更新 —— 全屏，从设置页「关于」进入
        GoRoute(
          path: update,
          builder: (context, state) => const UpdatePage(),
        ),

        // 标签壳：看板 / 路线 / 学习 / 统计 / 设置 —— 顺序与 shell.dart 的底栏
        // 一一对应，「学习」居中并放大。SOP 会话不在标签内（全屏沉浸）。
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: dashboard,
                  builder: (context, state) => const DashboardPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tracks,
                  builder: (context, state) => const TracksPage(),
                  routes: [
                    GoRoute(
                      path: ':trackId',
                      builder: (context, state) => NodesPage(
                        trackId: state.pathParameters['trackId']!,
                      ),
                      routes: [
                        GoRoute(
                          path: 'nodes/:nodeId',
                          builder: (context, state) => NodeDetailPage(
                            trackId: state.pathParameters['trackId']!,
                            nodeId: state.pathParameters['nodeId']!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: learn,
                  builder: (context, state) => const LearnPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: stats,
                  builder: (context, state) => const StatsPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: storageSettings,
                  builder: (context, state) => const StorageSettingsPage(),
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('页面不存在')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('找不到该页面'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go(learn),
                child: const Text('回到学习'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
