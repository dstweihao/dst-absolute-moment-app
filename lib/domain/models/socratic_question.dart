/// 苏格拉底诘问 — 节点内嵌的单点问题
///
/// 对应节点 YAML 中的 `socratic_questions` 数组元素。
/// 铁律：一次只抛 1 个聚焦问题，禁止堆叠复合大题。
class SocraticQuestion {
  /// 问题标识，如 `Q0_ground_zero`
  final String id;

  /// 难度层级标签，如「绝对零度破冰」「栈空间回收」，可为空
  final String? level;

  /// 问题正文
  final String text;

  const SocraticQuestion({
    required this.id,
    required this.text,
    this.level,
  });

  factory SocraticQuestion.fromMap(Map<dynamic, dynamic> map) {
    return SocraticQuestion(
      id: (map['id'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      level: map['level']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        if (level != null) 'level': level,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocraticQuestion &&
          other.id == id &&
          other.level == level &&
          other.text == text;

  @override
  int get hashCode => Object.hash(id, level, text);

  @override
  String toString() => 'SocraticQuestion($id)';
}
