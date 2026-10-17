/// 行动卡片 — 阶段⑤ 产出
///
/// 对应七阶段 SOP 的「转化落地」环节。四要素缺一不可：
/// 做什么、几点做、完成标准、对签单的贡献。
/// 铁律：AI 可以帮锐化措辞，禁止代做决策。
class ActionCard {
  /// 唯一标识，用于在 action-cards.md 中定位
  final String id;

  /// 来源打卡日期 YYYY-MM-DD
  final String sourceDate;

  /// 具体做什么
  final String what;

  /// 几点执行（自由文本，如「今天 14:00 前」）
  final String whenText;

  /// 完成标准
  final String criteria;

  /// 对签单的贡献
  final String businessValue;

  /// 是否已完成
  final bool done;

  final DateTime? completedAt;

  const ActionCard({
    required this.id,
    required this.sourceDate,
    required this.what,
    this.whenText = '',
    this.criteria = '',
    this.businessValue = '',
    this.done = false,
    this.completedAt,
  });

  factory ActionCard.fromMap(Map<dynamic, dynamic> map) {
    return ActionCard(
      id: (map['id'] ?? '').toString(),
      sourceDate: (map['source_date'] ?? '').toString(),
      what: (map['what'] ?? '').toString(),
      whenText: (map['when'] ?? '').toString(),
      criteria: (map['criteria'] ?? '').toString(),
      businessValue: (map['business_value'] ?? '').toString(),
      done: map['done'] == true || map['done'] == 'true',
      completedAt: _parseDate(map['completed_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'source_date': sourceDate,
        'what': what,
        'when': whenText,
        'criteria': criteria,
        'business_value': businessValue,
        'done': done,
        if (completedAt != null)
          'completed_at': completedAt!.toIso8601String(),
      };

  ActionCard copyWith({
    String? id,
    String? sourceDate,
    String? what,
    String? whenText,
    String? criteria,
    String? businessValue,
    bool? done,
    DateTime? completedAt,
  }) {
    return ActionCard(
      id: id ?? this.id,
      sourceDate: sourceDate ?? this.sourceDate,
      what: what ?? this.what,
      whenText: whenText ?? this.whenText,
      criteria: criteria ?? this.criteria,
      businessValue: businessValue ?? this.businessValue,
      done: done ?? this.done,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// 四要素是否都已填写
  bool get isComplete =>
      what.trim().isNotEmpty &&
      whenText.trim().isNotEmpty &&
      criteria.trim().isNotEmpty &&
      businessValue.trim().isNotEmpty;

  /// 缺失的要素，用于 UI 提示
  List<String> get missingFields => [
        if (what.trim().isEmpty) '具体做什么',
        if (whenText.trim().isEmpty) '几点执行',
        if (criteria.trim().isEmpty) '完成标准',
        if (businessValue.trim().isEmpty) '工程验证价值',
      ];

  /// 是否已逾期（有 when 文本但未完成）
  bool get isOverdue => !done && whenText.trim().isNotEmpty;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ActionCard && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ActionCard($id · $what)';
}
