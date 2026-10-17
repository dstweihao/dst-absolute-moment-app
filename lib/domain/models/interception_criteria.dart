/// 节点拦截条件 — 判定用户是否真的过关
///
/// 对应节点 YAML 中的 `interception` 段。这是「进度锁定铁律」的数据来源：
/// 未达验收标准则绝不放行，进度条锁死。
class InterceptionCriteria {
  /// 判定维度 —— 考官从哪些角度审视回答
  final List<String> judgmentDimensions;

  /// 最低通过线 —— 必须达到的底线
  final String minimumPassLine;

  /// 未通过时的处置 —— 如「动态插入补给站，降维后回归本节点」
  final String onFailure;

  const InterceptionCriteria({
    this.judgmentDimensions = const [],
    this.minimumPassLine = '',
    this.onFailure = '',
  });

  factory InterceptionCriteria.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const InterceptionCriteria();
    return InterceptionCriteria(
      judgmentDimensions: _stringList(map['judgment_dimensions']),
      minimumPassLine: (map['minimum_pass_line'] ?? '').toString(),
      onFailure: (map['on_failure'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'judgment_dimensions': judgmentDimensions,
        'minimum_pass_line': minimumPassLine,
        'on_failure': onFailure,
      };

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  bool get isEmpty =>
      judgmentDimensions.isEmpty && minimumPassLine.isEmpty && onFailure.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InterceptionCriteria &&
          other.minimumPassLine == minimumPassLine &&
          other.onFailure == onFailure &&
          _listEquals(other.judgmentDimensions, judgmentDimensions);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(judgmentDimensions),
        minimumPassLine,
        onFailure,
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
