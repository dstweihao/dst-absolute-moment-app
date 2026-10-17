import '../enums/app_enums.dart';

/// Track 内的一个学习阶段（对应路线图的「阶段一 ~ 阶段四」）
class TrackPhase {
  /// 阶段编号 1-4
  final int number;

  /// 阶段名，如「内存绝对控制权与语言底盘」
  final String name;

  /// 该阶段覆盖的进度区间
  final double startPercent;
  final double endPercent;

  const TrackPhase({
    required this.number,
    required this.name,
    this.startPercent = 0,
    this.endPercent = 0,
  });

  /// 标题文本，如「阶段一：内存绝对控制权 (0% → 30%)」
  String get displayTitle =>
      '阶段$number：$name (${startPercent.toStringAsFixed(0)}% → ${endPercent.toStringAsFixed(0)}%)';
}

/// 学习路线 — Track
///
/// 静态部分来自「个性化资源文件夹」（用户单独选定，任意结构），
/// 未设置时回落到内置标准课程 `StandardCurriculum`。
class Track {
  final String id;

  /// 显示名，如「C++ 高级开发」
  final String title;

  final String description;

  /// 该 track 归属的五轨轮转槽位
  final RotationSlot slot;

  /// WebDAV 上的根路径，如 `/AbsoluteGauge-Platform/tracks/cpp`
  final String remotePath;

  /// 阶段划分
  final List<TrackPhase> phases;

  /// 节点 id 有序列表（按 order）
  final List<String> nodeIds;

  /// 运行时状态
  final TrackStatus status;
  final DateTime? completedAt;

  const Track({
    required this.id,
    required this.title,
    this.description = '',
    this.slot = RotationSlot.cppBasics,
    this.remotePath = '',
    this.phases = const [],
    this.nodeIds = const [],
    this.status = TrackStatus.notStarted,
    this.completedAt,
  });

  Track copyWith({
    String? id,
    String? title,
    String? description,
    RotationSlot? slot,
    String? remotePath,
    List<TrackPhase>? phases,
    List<String>? nodeIds,
    TrackStatus? status,
    DateTime? completedAt,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      slot: slot ?? this.slot,
      remotePath: remotePath ?? this.remotePath,
      phases: phases ?? this.phases,
      nodeIds: nodeIds ?? this.nodeIds,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// 节点总数（不含 Bonus）
  int get totalNodes => nodeIds.length;

  /// 根据已通过节点数计算进度百分比
  double progressPercent(int passedCount) {
    if (totalNodes == 0) return 0;
    return (passedCount / totalNodes * 100).clamp(0, 100);
  }

  /// 找出某节点所属的阶段
  TrackPhase? phaseForNode(int nodePhaseNumber) {
    for (final p in phases) {
      if (p.number == nodePhaseNumber) return p;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Track($id · $title)';
}
