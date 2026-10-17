import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 非敏感的本地设置
///
/// 这里只放「这台设备自己的」偏好 —— 数据文件夹路径天然是设备相关的
/// （手机和电脑路径不可能一样），所以**不同步**，存本地即可。
/// 需要跨设备同步的配置（轮转比例、AI 模型名等）走 config.yaml。
class AppSettingsStore {
  static const _keyStorageRoot = 'storage_root_path';
  static const _keyLearningRoot = 'learning_root_path';
  static const _keyFirstRunDone = 'first_run_done';
  static const _keyThemeMode = 'theme_mode';

  /// 读取用户选定的数据文件夹；未设置时返回 null（由调用方决定默认值）
  Future<String?> loadStorageRoot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_keyStorageRoot);
      return (path == null || path.trim().isEmpty) ? null : path.trim();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveStorageRoot(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStorageRoot, path.trim());
  }

  Future<void> clearStorageRoot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStorageRoot);
  }

  /// 读取用户选定的「个性化资源文件夹」。
  ///
  /// 与数据文件夹**刻意分开**：这里只放个性化学习路线（节点 YAML），
  /// 是只读的补充内容来源；没设置（空串）就用内置标准课程。
  Future<String> loadLearningRoot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_keyLearningRoot);
      return path == null ? '' : path.trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> saveLearningRoot(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLearningRoot, path.trim());
  }

  Future<void> clearLearningRoot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLearningRoot);
  }

  /// 是否已完成首次引导（选择学习路径 / 个性化资源）
  Future<bool> isFirstRunDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyFirstRunDone) ?? false;
    } catch (_) {
      // 读失败按「未完成」处理，让用户走一遍引导
      return false;
    }
  }

  Future<void> setFirstRunDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstRunDone, true);
  }

  /// 外观模式。默认明亮 —— 未设置时按 light 处理。
  Future<ThemeMode> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyThemeMode);
      return switch (raw) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
    } catch (_) {
      return ThemeMode.light;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
  }
}
