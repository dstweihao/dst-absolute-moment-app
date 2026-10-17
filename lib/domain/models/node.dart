import '../enums/app_enums.dart';
import 'socratic_question.dart';
import 'interception_criteria.dart';

/// 学习节点 — 一个 Micro-Challenge 战斗单元
///
/// **一个关卡只讲一个概念**：`coreConcepts` / `questions` / `acceptanceCriteria`
/// 各自只保留一条，避免把一关塞成百科页。
///
/// 静态部分来自内置标准课程，或「个性化资源文件夹」里的节点 YAML
/// （任意嵌套，递归扫描；标记为 [isSupplementary] 的补充关）；运行时状态
/// （status / passedAt）来自本地进度记录，不写回 YAML。
class Node {
  // ---- 来自 YAML 的静态字段 ----
  final String id;
  final String title;
  final String description;

  /// 节点在路线中的序号（0 起）
  final int order;

  /// 所属阶段编号 1-4
  final int phase;
  final String phaseName;

  /// 该节点跨越的进度区间
  final double progressStart;
  final double progressEnd;

  final List<String> coreConcepts;
  final List<SocraticQuestion> questions;
  final InterceptionCriteria interception;
  final List<String> acceptanceCriteria;

  final String? nextNodeId;

  /// 前置节点 —— 未全部通过则本节点锁定（进度锁定铁律）
  final List<String> prerequisites;

  /// 是否为 100% 之后的 Bonus 实战节点
  final bool isBonus;

  /// 是否为用户个性化资源带来的**补充关**
  ///
  /// 补充关追加在标准路线末尾，不计入主线进度、不参与「今日攻坚」自动选关
  /// —— 它是额外的，不该顶替或拖慢标准路线。
  final bool isSupplementary;

  // ---- 运行时状态 ----
  final NodeStatus status;
  final DateTime? passedAt;

  const Node({
    required this.id,
    required this.title,
    this.description = '',
    this.order = 0,
    this.phase = 1,
    this.phaseName = '',
    this.progressStart = 0,
    this.progressEnd = 0,
    this.coreConcepts = const [],
    this.questions = const [],
    this.interception = const InterceptionCriteria(),
    this.acceptanceCriteria = const [],
    this.nextNodeId,
    this.prerequisites = const [],
    this.isBonus = false,
    this.isSupplementary = false,
    this.status = NodeStatus.notStarted,
    this.passedAt,
  });

  /// 从节点 YAML 解析。缺失字段一律取安全默认值，不抛异常
  /// —— 云端文件可能被手工编辑，必须容错。
  factory Node.fromYaml(Map<dynamic, dynamic> yaml, {String? trackId}) {
    final range = yaml['progress_range'];
    double start = 0;
    double end = 0;
    if (range is List && range.length >= 2) {
      start = _toDouble(range[0]);
      end = _toDouble(range[1]);
    }

    final rawQuestions = yaml['socratic_questions'];
    final questions = <SocraticQuestion>[];
    if (rawQuestions is List) {
      for (final q in rawQuestions) {
        if (q is Map) questions.add(SocraticQuestion.fromMap(q));
      }
    }

    return Node(
      id: (yaml['id'] ?? '').toString(),
      title: (yaml['title'] ?? '').toString(),
      description: (yaml['description'] ?? '').toString().trim(),
      order: (yaml['order'] is int) ? yaml['order'] as int : 0,
      phase: (yaml['phase'] is int) ? yaml['phase'] as int : 1,
      phaseName: (yaml['phase_name'] ?? '').toString(),
      progressStart: start,
      progressEnd: end,
      coreConcepts: _stringList(yaml['core_concepts']),
      questions: questions,
      interception: InterceptionCriteria.fromMap(
        yaml['interception'] is Map ? yaml['interception'] as Map : null,
      ),
      acceptanceCriteria: _stringList(yaml['acceptance_criteria']),
      nextNodeId: yaml['next_node']?.toString(),
      prerequisites: _stringList(yaml['prerequisites']),
      isBonus: _isBonusId(yaml['id']),
    );
  }

  /// Bonus 节点的 id 约定以 `bonus-` 开头
  static bool _isBonusId(dynamic rawId) =>
      (rawId ?? '').toString().startsWith('bonus-');

  /// 本地进度叠加静态数据后的新实例
  Node withStatus(NodeStatus newStatus, {DateTime? at}) => copyWith(
        status: newStatus,
        passedAt: newStatus == NodeStatus.passed
            ? (at ?? DateTime.now())
            : passedAt,
      );

  Node copyWith({
    String? id,
    String? title,
    String? description,
    int? order,
    int? phase,
    String? phaseName,
    double? progressStart,
    double? progressEnd,
    List<String>? coreConcepts,
    List<SocraticQuestion>? questions,
    InterceptionCriteria? interception,
    List<String>? acceptanceCriteria,
    String? nextNodeId,
    List<String>? prerequisites,
    bool? isBonus,
    bool? isSupplementary,
    NodeStatus? status,
    DateTime? passedAt,
  }) {
    return Node(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      phase: phase ?? this.phase,
      phaseName: phaseName ?? this.phaseName,
      progressStart: progressStart ?? this.progressStart,
      progressEnd: progressEnd ?? this.progressEnd,
      coreConcepts: coreConcepts ?? this.coreConcepts,
      questions: questions ?? this.questions,
      interception: interception ?? this.interception,
      acceptanceCriteria: acceptanceCriteria ?? this.acceptanceCriteria,
      nextNodeId: nextNodeId ?? this.nextNodeId,
      prerequisites: prerequisites ?? this.prerequisites,
      isBonus: isBonus ?? this.isBonus,
      isSupplementary: isSupplementary ?? this.isSupplementary,
      status: status ?? this.status,
      passedAt: passedAt ?? this.passedAt,
    );
  }

  // ---- 派生属性 ----

  /// 列表展示用的编号，如 `00`
  String get displayNumber =>
      isBonus ? 'Bonus' : order.toString().padLeft(2, '0');

  /// 进度区间文本，如 `0% → 5%`
  String get progressRangeText =>
      '${progressStart.toStringAsFixed(0)}% → ${progressEnd.toStringAsFixed(0)}%';

  /// 是否已通过
  bool get isPassed => status == NodeStatus.passed;

  /// 给定已通过节点集合，判断本节点前置是否满足
  bool prerequisitesMet(Set<String> passedNodeIds) =>
      prerequisites.every(passedNodeIds.contains);

  /// 首个诘问，用于列表预览
  SocraticQuestion? get firstQuestion =>
      questions.isEmpty ? null : questions.first;

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Node && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Node($id · $title)';
}
