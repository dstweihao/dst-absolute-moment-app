import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'data/ai/ai_client.dart';
import 'data/ai/anthropic_client.dart';
import 'data/ai/openai_client.dart';
import 'data/app_paths.dart';
import 'data/credentials/credentials_store.dart';
import 'data/repositories/checkin_repository.dart';
import 'data/repositories/config_repository.dart';
import 'data/repositories/resource_scanner.dart';
import 'data/repositories/track_repository.dart';
import 'data/settings/app_settings_store.dart';
import 'data/storage/file_store.dart';
import 'data/storage/file_store_factory.dart';
import 'data/updates/update_client.dart';
import 'data/updates/update_config.dart';
import 'data/updates/update_installer.dart';
import 'domain/enums/app_enums.dart';
import 'domain/models/action_card.dart';
import 'domain/models/ai_settings.dart';
import 'domain/models/app_config.dart';
import 'domain/models/checkin.dart';
import 'domain/models/source_material.dart';
import 'domain/models/node.dart';
import 'domain/models/player_progress.dart';
import 'domain/models/track.dart';
import 'domain/models/update_info.dart';
import 'domain/models/update_status.dart';

/// 启动期解析出的数据文件夹。**必须在 `ProviderScope` 里 override** ——
/// 解析默认值要读 SharedPreferences / path_provider，是异步的，
/// 放在 `main()` 里 await 完再注入，仓库层就能保持同步。
final initialStorageRootProvider = Provider<String>((ref) {
  throw StateError(
    'initialStorageRootProvider 必须在 ProviderScope 中 override；'
    '请通过 AbsoluteMomentBootstrap 启动。',
  );
});

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsStore();
});

/// 启动期从本地偏好解析出的外观模式。**必须在 `ProviderScope` 里 override**，
/// 解析要读 SharedPreferences，异步完成后再注入（见 `main()`）。
final initialThemeModeProvider =
    Provider<ThemeMode>((ref) => ThemeMode.light);

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(appSettingsStoreProvider).saveThemeMode(mode);
  }
}

final storageRootProvider =
    NotifierProvider<StorageRootNotifier, String>(StorageRootNotifier.new);

class StorageRootNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(initialStorageRootProvider);

  Future<void> changeTo(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == state) return;

    await ref.read(appSettingsStoreProvider).saveStorageRoot(trimmed);
    state = trimmed;
  }

  /// 只清本地覆盖，不动磁盘。本次会话仍用当前目录，
  /// 是否顺带 changeTo(defaultPath) 交给调用方决定。
  Future<void> useDefault() async {
    await ref.read(appSettingsStoreProvider).clearStorageRoot();
  }
}

/// 启动后做一次探针写入，用来区分「目录不存在」和「存在但只读」。
final storageStatusProvider = FutureProvider<FileStore>((ref) async {
  final store = ref.watch(fileStoreProvider);
  await store.testConnection();
  return store;
});

/// 根目录一变，依赖它的仓库与所有页面数据自动重建。
final fileStoreProvider = Provider<FileStore>((ref) {
  return createFileStore(ref.watch(storageRootProvider));
});

/// 启动期解析出的个性化资源文件夹。
///
/// **与数据文件夹刻意分开**：数据文件夹管 APP 自己的数据（打卡/行动卡片）
/// 并交给坚果云同步；这里只管个性化的学习资源（节点 YAML），只读、不写。
/// 空串 = 未设置 → 只有内置标准路线。
///
/// 语义是**补充**而非替换：内置标准路线始终生效，这里扫出来的节点
/// 作为「补充关」追加在路线末尾。
final initialLearningRootProvider = Provider<String>((ref) => '');

final learningRootProvider =
    NotifierProvider<LearningRootNotifier, String>(LearningRootNotifier.new);

class LearningRootNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(initialLearningRootProvider);

  Future<void> changeTo(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == state) return;

    await ref.read(appSettingsStoreProvider).saveLearningRoot(trimmed);
    state = trimmed;
  }

  /// 「补充内容不想要了」的逃生出口：清掉后立即回到打包在 APP 内的
  /// 通用标准路线，无需删磁盘上的任何文件。
  Future<void> clear() async {
    if (state.isEmpty) return;
    await ref.read(appSettingsStoreProvider).clearLearningRoot();
    state = '';
  }
}

/// 未设置时为 null —— 仓库据此只返回内置标准路线。
final learningFileStoreProvider = Provider<FileStore?>((ref) {
  final root = ref.watch(learningRootProvider);
  return root.isEmpty ? null : createFileStore(root);
});

/// 路线侧与 SOP 侧共用同一个实例，扫描结果整体缓存：分成两个仓库各扫一遍
/// 会让 WebDAV 这类远程盘付双倍往返。
final resourceScannerProvider = Provider<ResourceScanner>((ref) {
  return ResourceScanner(ref.watch(learningFileStoreProvider));
});

/// 阶段 0 的输入源物料，与 [nodesProvider] 同源不同桶：能解析成节点的
/// YAML 进路线，其余文档进这里。没有它，拆塔官只能问空对空的八股文。
final materialsProvider = FutureProvider<List<SourceMaterial>>((ref) async {
  final scan = await ref.watch(resourceScannerProvider).scan();
  return scan.materials;
});

final supportsCustomFolderProvider = Provider<bool>((ref) => supportsCustomFolder);

/// 设备本地加密，不随数据文件夹同步。
final secretStoreProvider = Provider<SecretStore>((ref) => SecretStore());

final aiApiKeyProvider = FutureProvider<String?>((ref) {
  return ref.watch(secretStoreProvider).loadAiApiKey();
});

final checkinRepositoryProvider = Provider<CheckinRepository>((ref) {
  return CheckinRepository(ref.watch(fileStoreProvider));
});

final trackRepositoryProvider = Provider<TrackRepository>((ref) {
  return TrackRepository(ref.watch(resourceScannerProvider));
});

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return ConfigRepository(ref.watch(fileStoreProvider));
});

final appConfigProvider = FutureProvider<AppConfig>((ref) {
  return ref.watch(configRepositoryProvider).load();
});

final aiSettingsProvider = Provider<AiSettings>((ref) {
  return ref.watch(appConfigProvider).value?.ai ?? AiSettings.defaults;
});

/// 未配置或未填 key 时返回 null —— 上层据此降级为自评模式。
final aiClientProvider = Provider<AiClient?>((ref) {
  final settings = ref.watch(aiSettingsProvider);
  if (!settings.isConfigured) return null;

  final apiKey = ref.watch(aiApiKeyProvider).value;
  if (apiKey == null || apiKey.trim().isEmpty) return null;

  final AiClient client = switch (settings.protocol) {
    AiProtocol.openai => OpenAiClient(settings: settings, apiKey: apiKey),
    AiProtocol.anthropic =>
      AnthropicClient(settings: settings, apiKey: apiKey),
  };

  ref.onDispose(client.dispose);
  return client;
});

final aiAvailableProvider = Provider<bool>((ref) {
  return ref.watch(aiClientProvider) != null;
});

final allTracksProvider = FutureProvider<List<Track>>((ref) {
  return ref.watch(trackRepositoryProvider).loadAll();
});

final nodesProvider =
    FutureProvider.family<List<Node>, String>((ref, trackId) {
  return ref.watch(trackRepositoryProvider).loadNodes(trackId);
});

/// 取自打卡记录里非空的 nodeId —— 节点 id 就是进度的持久键。
final passedNodeIdsProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(checkinRepositoryProvider).passedNodeIds();
});

final activeTrackIdProvider = Provider<String>((ref) {
  final config = ref.watch(appConfigProvider).value;
  return config?.activeTrackId ?? TrackCatalog.cppId;
});

final todaysNodeProvider = FutureProvider<Node?>((ref) async {
  final trackId = ref.watch(activeTrackIdProvider);
  final nodes = await ref.watch(nodesProvider(trackId).future);
  final passed = await ref.watch(passedNodeIdsProvider.future);
  return ref.watch(trackRepositoryProvider).nextNode(nodes, passed);
});

final activeLearningNodeIdProvider =
    NotifierProvider<ActiveLearningNodeIdNotifier, String?>(
        ActiveLearningNodeIdNotifier.new);

class ActiveLearningNodeIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? nodeId) {
    state = nodeId;
  }
}


/// 只计内置主线，补充关不进分母。
final overallProgressProvider = FutureProvider<double>((ref) async {
  final trackId = ref.watch(activeTrackIdProvider);
  final nodes = await ref.watch(nodesProvider(trackId).future);
  final passed = await ref.watch(passedNodeIdsProvider.future);
  return ref.watch(trackRepositoryProvider).overallProgress(nodes, passed);
});

/// 倒序（新 → 旧）。统计页的「最近 N 次」窗口依赖这个顺序。
final allCheckinsProvider = FutureProvider<List<Checkin>>((ref) {
  return ref.watch(checkinRepositoryProvider).listAll();
});

final currentStreakProvider = FutureProvider<int>((ref) {
  return ref.watch(checkinRepositoryProvider).currentStreak();
});

final longestStreakProvider = FutureProvider<int>((ref) {
  return ref.watch(checkinRepositoryProvider).longestStreak();
});

/// 全部由打卡记录与已通过节点数派生，不新增存储。
final playerProgressProvider = FutureProvider<PlayerProgress>((ref) async {
  final checkins = await ref.watch(allCheckinsProvider.future);
  final passed = await ref.watch(passedNodeIdsProvider.future);
  final streak = await ref.watch(currentStreakProvider.future);
  return PlayerProgress.from(
    checkins,
    clearedNodes: passed.length,
    streak: streak,
  );
});

final actionCardsProvider = FutureProvider<List<ActionCardView>>((ref) async {
  final cards = await ref.watch(checkinRepositoryProvider).allActionCards();
  return cards
      .map((c) => ActionCardView(card: c, date: c.sourceDate))
      .toList();
});

final hasCheckedInTodayProvider = FutureProvider<bool>((ref) async {
  final today = _todayString();
  final checkins = await ref.watch(allCheckinsProvider.future);
  return checkins.any((c) => c.date == today);
});

/// 运行时读到的应用版本。Web 拿不到、Windows debug 偶发陈旧，都兜到常量。
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    return version.isEmpty ? UpdateConfig.fallbackVersion : version;
  } catch (_) {
    return UpdateConfig.fallbackVersion;
  }
});

final updateClientProvider = Provider<UpdateClient>((ref) {
  final client = UpdateClient();
  ref.onDispose(client.close);
  return client;
});

typedef UpdateInstallerFn = Future<InstallResult> Function(
  ReleaseInfo release, {
  http.Client? httpClient,
  void Function(double? progress)? onProgress,
});

final updateInstallerProvider =
    Provider<UpdateInstallerFn>((ref) => installUpdate);

typedef OpenReleasePageFn = Future<InstallResult> Function(String htmlUrl);

final openReleasePageProvider =
    Provider<OpenReleasePageFn>((ref) => openReleasePage);

/// 检查结果常驻内存：启动时静默查一次，设置页与更新页共用同一份状态。
final updateStatusProvider =
    NotifierProvider<UpdateStatusNotifier, UpdateStatus>(
  UpdateStatusNotifier.new,
);

class UpdateStatusNotifier extends Notifier<UpdateStatus> {
  @override
  UpdateStatus build() => const UpdateIdle();

  Future<void> check() async {
    if (state is UpdateChecking) return;
    state = const UpdateChecking();

    try {
      final current = await ref.read(appVersionProvider.future);
      final latest = await ref.read(updateClientProvider).checkLatest();

      if (latest == null) {
        state = UpdateUpToDate(currentVersion: current);
        return;
      }

      state = (!latest.isPrerelease && isNewerVersion(latest.tagName, current))
          ? UpdateAvailable(currentVersion: current, release: latest)
          : UpdateUpToDate(
              currentVersion: current,
              latestVersion: latest.tagName,
            );
    } on Object catch (e) {
      state = UpdateCheckFailed(
        e is UpdateException ? e.message : '检查更新失败',
      );
    }
  }
}

/// 行动卡片 + 来源日期，供列表展示与勾选完成
class ActionCardView {
  final ActionCard card;
  final String date;

  const ActionCardView({required this.card, required this.date});

  bool get isDone => card.done;
  String get what => card.what;
  String get whenText => card.whenText;
}

String _todayString() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

final todayStringProvider = Provider<String>((ref) => _todayString());
