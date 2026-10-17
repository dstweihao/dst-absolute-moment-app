import 'package:absolute_moment_app/core/constants/app_constants.dart';

/// 绝对时刻APP — 核心枚举定义
///
/// 所有枚举均提供 `fromString` 以便从 Markdown YAML 头部 / JSON 反序列化，
/// 未知值一律回落到安全的默认值，绝不抛异常（云端文件可能被手工编辑出错）。

/// 节点状态
enum NodeStatus {
  notStarted,
  inProgress,
  sideQuestActive,
  passed;

  static NodeStatus fromString(String? s) {
    return NodeStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => NodeStatus.notStarted,
    );
  }

  String get label => switch (this) {
        NodeStatus.notStarted => '未开始',
        NodeStatus.inProgress => '进行中',
        NodeStatus.sideQuestActive => '支线进行中',
        NodeStatus.passed => '已通过',
      };

  /// 是否已解锁（可进入 SOP）
  bool get isUnlocked => this != NodeStatus.notStarted;
}

/// SOP 七阶段类型
enum SopStageType {
  recall,
  questioning,
  breakdown,
  verification,
  translation,
  actionCard,
  selfRating;

  // 声明顺序 0-6 恰好等于阶段序号：SopStages 的查表全靠这个隐式契约

  /// 该阶段的目标分钟数
  int get targetMinutes => SopStages.defaultMinutes[index] ?? 0;

  /// 阶段完整标签，如「① 诘问」
  String get label => SopStages.labels[index] ?? '';

  /// 阶段简短说明
  String get description => SopStages.descriptions[index] ?? '';

  /// 该阶段是否允许 AI 介入
  ///
  /// ⓪ 昨日提取是纯记忆测试，⑥ 自评必须用户自己打分 —— AI 在场都会污染结果。
  bool get allowsAi =>
      this != SopStageType.recall && this != SopStageType.selfRating;

  static SopStageType fromIndex(int i) =>
      SopStageType.values[i.clamp(0, SopStageType.values.length - 1)];

  static SopStageType fromString(String? s) {
    return SopStageType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => SopStageType.recall,
    );
  }
}

/// 阶段完成状态
enum StageCompletionStatus {
  pending,
  inProgress,
  completed,
  skipped;

  static StageCompletionStatus fromString(String? s) {
    return StageCompletionStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => StageCompletionStatus.pending,
    );
  }

  bool get isDone =>
      this == StageCompletionStatus.completed ||
      this == StageCompletionStatus.skipped;
}

/// Track 状态
enum TrackStatus {
  notStarted,
  inProgress,
  completed;

  static TrackStatus fromString(String? s) {
    return TrackStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TrackStatus.notStarted,
    );
  }
}

/// 五轨轮转槽位
enum RotationSlot {
  cppBasics,
  cppArchitecture,
  businessAlignment,
  valuePromotion,
  techIpReview;

  String get label => RotationConfig.rotationQueue[index];

  int get weight => RotationConfig.defaultWeights[label] ?? 1;

  static RotationSlot fromIndex(int i) =>
      RotationSlot.values[i.clamp(0, RotationSlot.values.length - 1)];

  static RotationSlot fromString(String? s) {
    return RotationSlot.values.firstWhere(
      (e) => e.name == s,
      orElse: () => RotationSlot.cppBasics,
    );
  }
}

/// AI 协议类型
enum AiProtocol {
  openai,     // OpenAI 兼容：POST {base_url}/chat/completions
  anthropic;  // Anthropic 兼容：POST {base_url}/v1/messages

  String get label => switch (this) {
        AiProtocol.openai => 'OpenAI 兼容',
        AiProtocol.anthropic => 'Anthropic 兼容',
      };

  static AiProtocol fromString(String? s) {
    return AiProtocol.values.firstWhere(
      (e) => e.name == s,
      orElse: () => AiProtocol.openai,
    );
  }
}

/// 难度区间语义
enum DifficultyBand {
  tooEasy,
  sweetSpot,
  tooHard;

  static DifficultyBand fromScore(int score) {
    if (score < DifficultyConfig.sweetSpotMin) return DifficultyBand.tooEasy;
    if (score > DifficultyConfig.sweetSpotMax) return DifficultyBand.tooHard;
    return DifficultyBand.sweetSpot;
  }

  String get label => switch (this) {
        DifficultyBand.tooEasy => '太简单',
        DifficultyBand.sweetSpot => '甜蜜点',
        DifficultyBand.tooHard => '太难',
      };
}
