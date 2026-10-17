import 'package:yaml/yaml.dart';

import '../../domain/models/ai_settings.dart';
import '../../domain/models/app_config.dart';
import '../app_paths.dart';
import '../serialization/frontmatter.dart';
import '../storage/file_store.dart';

/// 全局配置仓库
///
/// 读写 `/AbsoluteMoment/config.yaml`。该文件**跨设备同步**，
/// 因此绝不含任何密钥（密钥在 `CredentialsStore` 里设备本地加密）。
class ConfigRepository {
  final FileStore client;

  /// 进程内缓存，避免每次读配置都发请求
  AppConfig? _cache;

  ConfigRepository(this.client);

  /// 读取配置。文件不存在时返回默认配置。
  Future<AppConfig> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    final raw = await client.readOrNull(AppPaths.configFile);
    if (raw == null) {
      _cache = AppConfig.defaults;
      return _cache!;
    }

    try {
      // config.yaml 是纯 YAML（不带 Markdown 正文），直接解析
      final loaded = loadYaml(raw);
      if (loaded is! Map) {
        _cache = AppConfig.defaults;
        return _cache!;
      }
      _cache = AppConfig.fromMap(loaded);
      return _cache!;
    } catch (_) {
      // 配置被改坏时回落到默认值，不阻塞启动
      _cache = AppConfig.defaults;
      return _cache!;
    }
  }

  /// 写回配置（先确保父目录存在）
  Future<void> save(AppConfig config) async {
    await client.ensureDirectory(AppPaths.appRoot);
    await client.write(
      AppPaths.configFile,
      Frontmatter.dumpYaml(config.toMap()),
    );
    _cache = config;
  }

  /// 只更新 AI 配置段，保留其余设置
  Future<AppConfig> saveAiSettings(AiSettings ai) async {
    final current = await load();
    final next = current.copyWith(ai: ai);
    await save(next);
    return next;
  }

  /// 设置当前活跃 track
  Future<AppConfig> setActiveTrack(String trackId) async {
    final current = await load();
    final next = current.copyWith(activeTrackId: trackId);
    await save(next);
    return next;
  }

  /// 更新五轨轮转权重
  Future<AppConfig> setRotationWeights(Map<String, int> weights) async {
    final current = await load();
    final next = current.copyWith(rotationWeights: weights);
    await save(next);
    return next;
  }

  void invalidate() => _cache = null;
}
