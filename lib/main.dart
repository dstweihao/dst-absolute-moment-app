import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/settings/app_settings_store.dart';
import 'data/storage/file_store_factory.dart';
import 'providers.dart';

/// 启动引导
///
/// 做两件事：
/// 1. 把「数据文件夹」解析出来并注入 —— 用户选定优先，否则用平台默认。
/// 2. 判断是否首次使用 —— 首次则先进引导页（选学习路径 / 个性化资源）。
/// **不做任何连接检查**：配置 AI 是之后的事。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final root = await _resolveStorageRoot();
  final learningRoot = await _resolveLearningRoot();
  final firstRunDone = await _resolveFirstRunDone();
  final themeMode = await _resolveThemeMode();

  runApp(
    ProviderScope(
      overrides: [
        initialStorageRootProvider.overrideWithValue(root),
        initialLearningRootProvider.overrideWithValue(learningRoot),
        initialThemeModeProvider.overrideWithValue(themeMode),
      ],
      child: AbsoluteMomentApp(initialFirstRunDone: firstRunDone),
    ),
  );
}

Future<String> _resolveStorageRoot() async {
  try {
    final saved = await AppSettingsStore().loadStorageRoot();
    if (saved != null && saved.isNotEmpty) return saved;
  } catch (_) {
    // 读设置失败不该阻塞启动，退回默认目录
  }

  try {
    return await defaultRootPath();
  } catch (_) {
    // Web 端没有本地目录概念，返回空串由内存存储忽略
    return '';
  }
}

/// 个性化资源文件夹。未设置时返回空串 —— 空串即「用内置标准课程」。
///
/// 与数据文件夹**分开解析**：不设置个性化资源文件夹也完全可用，
/// 这正是默认状态（内置标准课程开箱即用）。
Future<String> _resolveLearningRoot() async {
  try {
    return await AppSettingsStore().loadLearningRoot();
  } catch (_) {
    return '';
  }
}

Future<bool> _resolveFirstRunDone() async {
  // 最小可执行方案：直达 C++ 标准学习路线，无需任何引导页阻断
  return true;
}

/// 外观偏好。读不到时用明亮主题（默认）。
Future<ThemeMode> _resolveThemeMode() async {
  try {
    return await AppSettingsStore().loadThemeMode();
  } catch (_) {
    return ThemeMode.light;
  }
}
