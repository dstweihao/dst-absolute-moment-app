import '../../core/constants/app_constants.dart';
import 'ai_settings.dart';

/// 全局配置 — 对应 `/AbsoluteMoment/config.yaml`
///
/// 跨设备同步，**不含任何密钥**。
class AppConfig {
  /// 配置结构版本，用于未来迁移
  final int schemaVersion;

  /// 当前活跃的 track id
  final String? activeTrackId;

  /// 五轨轮转权重，默认 2:1:1:1:1
  final Map<String, int> rotationWeights;

  /// AI 接口配置
  final AiSettings ai;

  const AppConfig({
    this.schemaVersion = currentSchemaVersion,
    this.activeTrackId,
    this.rotationWeights = const {},
    this.ai = const AiSettings(),
  });

  static const int currentSchemaVersion = 1;

  static const AppConfig defaults = AppConfig(
    rotationWeights: RotationConfig.defaultWeights,
  );

  AppConfig copyWith({
    int? schemaVersion,
    String? activeTrackId,
    Map<String, int>? rotationWeights,
    AiSettings? ai,
  }) {
    return AppConfig(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      activeTrackId: activeTrackId ?? this.activeTrackId,
      rotationWeights: rotationWeights ?? this.rotationWeights,
      ai: ai ?? this.ai,
    );
  }

  /// 取某槽位的权重，未配置则回落到常量默认值
  int weightFor(String slotLabel) =>
      rotationWeights[slotLabel] ??
      RotationConfig.defaultWeights[slotLabel] ??
      1;

  /// 权重是否已偏离默认值（用于设置页提示）
  bool get isRotationCustomized {
    for (final entry in RotationConfig.defaultWeights.entries) {
      if (weightFor(entry.key) != entry.value) return true;
    }
    return false;
  }

  factory AppConfig.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return defaults;

    final weights = <String, int>{};
    final rawWeights = map['rotation_weights'];
    if (rawWeights is Map) {
      for (final entry in rawWeights.entries) {
        final v = entry.value;
        final parsed = v is int ? v : int.tryParse(v?.toString() ?? '');
        if (parsed != null) weights[entry.key.toString()] = parsed;
      }
    }

    final rawAi = map['ai'];

    return AppConfig(
      schemaVersion: _toInt(map['schema_version'], currentSchemaVersion),
      activeTrackId: map['active_track']?.toString(),
      rotationWeights:
          weights.isEmpty ? RotationConfig.defaultWeights : weights,
      ai: AiSettings.fromMap(rawAi is Map ? rawAi : null),
    );
  }

  Map<String, dynamic> toMap() => {
        'schema_version': schemaVersion,
        if (activeTrackId != null) 'active_track': activeTrackId,
        'rotation_weights': rotationWeights,
        'ai': ai.toMap(),
      };

  static int _toInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          other.schemaVersion == schemaVersion &&
          other.activeTrackId == activeTrackId &&
          other.ai == ai &&
          _mapEquals(other.rotationWeights, rotationWeights);

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        activeTrackId,
        ai,
        Object.hashAllUnordered(
          rotationWeights.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  static bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
