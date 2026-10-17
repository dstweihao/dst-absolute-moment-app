import 'action_card.dart';

/// 反方证据 — 阶段③ 产出
///
/// 强制结构化模板：「我原以为 X，但实际上 Y」。
/// 这是苏格拉底反诘法的核心动作 —— 必须先暴露无知，再填补无知。
/// 铁律：至少 1 条才能从阶段③推进到阶段④，否则进度锁死。
class CounterEvidence {
  /// 我原以为…
  final String assumed;

  /// 但实际上…
  final String actual;

  const CounterEvidence({this.assumed = '', this.actual = ''});

  factory CounterEvidence.fromMap(Map<dynamic, dynamic> map) {
    return CounterEvidence(
      assumed: (map['assumed'] ?? '').toString(),
      actual: (map['actual'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {'assumed': assumed, 'actual': actual};

  /// 该条证据是否填写完整
  bool get isComplete =>
      assumed.trim().isNotEmpty && actual.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CounterEvidence &&
          other.assumed == assumed &&
          other.actual == actual;

  @override
  int get hashCode => Object.hash(assumed, actual);
}

/// 打卡记录 — 一次完整的苏格拉底七阶段闭环
///
/// 存储为 `/AbsoluteMoment/checkins/YYYY-MM-DD.md`，
/// 人可读、程序可解析、桌面端可直接用记事本编辑。
class Checkin {
  /// 日期，YYYY-MM-DD
  final String date;

  final String trackId;
  final String nodeId;
  final String nodeTitle;

  /// 本次闭环实际用时（分钟）
  final int durationMinutes;

  /// 是否走完全部七阶段
  final bool completed;

  /// 是否调用过 AI 拷问
  final bool aiAssisted;

  /// AI 拷问轮次
  final int aiRounds;

  // ---- 阶段 0：物料与背景建档 ----
  /// 本次选定的输入源 —— 个性化资源文件夹内的逻辑路径
  ///
  /// 只存路径不存正文：正文在提问时按路径回查文件夹，这样物料被编辑过
  /// 或删掉之后，记录不会留着一份过期的副本。
  final List<String> materials;

  /// 手写补充的背景说明 —— 文件夹里没有、但今天需要交代给 AI 的上下文
  final String background;

  // ---- ⓪ 昨日提取：3 条关键发现 ----
  final List<String> yesterdayFindings;

  /// 本次是否跳过了阶段⓪（仅首次会话允许）
  final bool recallSkipped;

  // ---- ① 诘问 ----
  final String socraticQuestion;
  final String userAnswer;

  // ---- ② 拆解 ----
  final String weakestAssumption;

  // ---- ③ 验证 ----
  final List<CounterEvidence> counterEvidence;

  // ---- ④ 转化 ----
  final String businessTranslation;

  // ---- ⑤ 行动卡片 ----
  final ActionCard? actionCard;

  // ---- ⑥ 自评 ----
  /// 难度自评 1-10，甜蜜点 3-7
  final int? difficulty;

  const Checkin({
    required this.date,
    this.trackId = '',
    this.nodeId = '',
    this.nodeTitle = '',
    this.durationMinutes = 0,
    this.completed = false,
    this.aiAssisted = false,
    this.aiRounds = 0,
    this.materials = const [],
    this.background = '',
    this.yesterdayFindings = const [],
    this.recallSkipped = false,
    this.socraticQuestion = '',
    this.userAnswer = '',
    this.weakestAssumption = '',
    this.counterEvidence = const [],
    this.businessTranslation = '',
    this.actionCard,
    this.difficulty,
  });

  Checkin copyWith({
    String? date,
    String? trackId,
    String? nodeId,
    String? nodeTitle,
    int? durationMinutes,
    bool? completed,
    bool? aiAssisted,
    int? aiRounds,
    List<String>? materials,
    String? background,
    List<String>? yesterdayFindings,
    bool? recallSkipped,
    String? socraticQuestion,
    String? userAnswer,
    String? weakestAssumption,
    List<CounterEvidence>? counterEvidence,
    String? businessTranslation,
    ActionCard? actionCard,
    int? difficulty,
  }) {
    return Checkin(
      date: date ?? this.date,
      trackId: trackId ?? this.trackId,
      nodeId: nodeId ?? this.nodeId,
      nodeTitle: nodeTitle ?? this.nodeTitle,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      completed: completed ?? this.completed,
      aiAssisted: aiAssisted ?? this.aiAssisted,
      aiRounds: aiRounds ?? this.aiRounds,
      materials: materials ?? this.materials,
      background: background ?? this.background,
      yesterdayFindings: yesterdayFindings ?? this.yesterdayFindings,
      recallSkipped: recallSkipped ?? this.recallSkipped,
      socraticQuestion: socraticQuestion ?? this.socraticQuestion,
      userAnswer: userAnswer ?? this.userAnswer,
      weakestAssumption: weakestAssumption ?? this.weakestAssumption,
      counterEvidence: counterEvidence ?? this.counterEvidence,
      businessTranslation: businessTranslation ?? this.businessTranslation,
      actionCard: actionCard ?? this.actionCard,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  // ---- 派生属性 ----

  /// 已填写完整的反方证据条数
  int get validEvidenceCount =>
      counterEvidence.where((e) => e.isComplete).length;

  /// 是否满足阶段③的硬性通关条件（≥1 条完整证据）
  bool get hasRequiredEvidence => validEvidenceCount >= 1;

  /// 难度所处的区间
  String get difficultyBandLabel {
    final d = difficulty;
    if (d == null) return '未评分';
    if (d < 3) return '太简单';
    if (d > 7) return '太难';
    return '甜蜜点';
  }

  /// 从解析后的 Markdown 映射构造。容错：任何缺失字段取默认值。
  factory Checkin.fromMap(Map<dynamic, dynamic> map) {
    final rawEvidence = map['counter_evidence'];
    final evidence = <CounterEvidence>[];
    if (rawEvidence is List) {
      for (final e in rawEvidence) {
        if (e is Map) evidence.add(CounterEvidence.fromMap(e));
      }
    }

    final rawFindings = map['yesterday_findings'];
    final findings = <String>[];
    if (rawFindings is List) {
      findings.addAll(rawFindings.map((e) => e.toString()));
    }

    final rawCard = map['action_card'];
    final card = rawCard is Map ? ActionCard.fromMap(rawCard) : null;

    final rawMaterials = map['materials'];
    final materials = <String>[];
    if (rawMaterials is List) {
      materials.addAll(rawMaterials.map((e) => e.toString()));
    }

    return Checkin(
      date: (map['date'] ?? '').toString(),
      trackId: (map['track'] ?? '').toString(),
      nodeId: (map['node'] ?? '').toString(),
      nodeTitle: (map['node_title'] ?? '').toString(),
      durationMinutes: _toInt(map['duration_minutes']),
      completed: map['completed'] == true || map['completed'] == 'true',
      aiAssisted: map['ai_assisted'] == true || map['ai_assisted'] == 'true',
      aiRounds: _toInt(map['ai_rounds']),
      materials: materials,
      background: (map['background'] ?? '').toString(),
      yesterdayFindings: findings,
      recallSkipped:
          map['recall_skipped'] == true || map['recall_skipped'] == 'true',
      socraticQuestion: (map['socratic_question'] ?? '').toString(),
      userAnswer: (map['user_answer'] ?? '').toString(),
      weakestAssumption: (map['weakest_assumption'] ?? '').toString(),
      counterEvidence: evidence,
      businessTranslation: (map['business_translation'] ?? '').toString(),
      actionCard: card,
      difficulty: map['difficulty'] == null ? null : _toInt(map['difficulty']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Checkin && other.date == date;

  @override
  int get hashCode => date.hashCode;

  @override
  String toString() => 'Checkin($date · $nodeId)';
}
