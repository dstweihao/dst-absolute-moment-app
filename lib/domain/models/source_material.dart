/// 输入源物料 —— 个性化资源文件夹里的**非节点文档**
///
/// 同一个文件夹养两种东西，用途完全不同：
/// - 能解析成节点的 YAML → 「补充关」，进路线，算在学习进度里
/// - `.md` / `.txt` 这类文档 → 「物料」，进 SOP 阶段 0，成为 AI 拷问的
///   真实业务背景
///
/// 分开的理由：练习题和背景资料是两件事。把笔记塞进路线会把路线撑爆，
/// 但它恰恰是 AI 该锚定的东西 —— 没有它，拆塔官只能问空对空的八股文。
///
/// 命名为 SourceMaterial 而非 Material，是为了避开 Flutter 的同名 widget。
class SourceMaterial {
  /// 跨天唯一标识这一份物料
  final String path;

  /// 文件名去掉扩展名
  final String name;

  /// 文档正文 —— **全量**，不做任何截断。
  ///
  /// 曾经按 8000 字砍过一刀，结果是 AI 拿到的背景在半句话上断掉，
  /// 后面最关键的结论段整段丢失。背景资料要么全给，要么别给，
  /// 给一半比不给更坏。
  final String content;

  const SourceMaterial({
    required this.path,
    required this.name,
    this.content = '',
  });

  /// 空文件只是占位
  bool get hasContent => content.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SourceMaterial && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'SourceMaterial($path)';
}
