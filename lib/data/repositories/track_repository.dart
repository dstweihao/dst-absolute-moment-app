import '../../domain/enums/app_enums.dart';
import '../../domain/models/node.dart';
import '../../domain/models/track.dart';
import '../app_paths.dart';
import '../seed/standard_curriculum.dart';
import '../storage/file_store.dart';
import 'resource_scanner.dart';

/// Track 与节点仓库
///
/// **只读**。节点数据有两个来源，是**叠加**关系而不是二选一：
///
/// 1. **内置标准课程** [StandardCurriculum] —— 永远生效，是路线的主干。
/// 2. **个性化资源文件夹**（用户在设置里单独选定，只读）—— 目录结构**任意**，
///    由 [ResourceScanner] 从根递归扫描。扫出来的节点标记为
///    [Node.isSupplementary] 后**追加在末尾**。
///
/// 补充关不占主线进度、不参与「今日攻坚」的自动选关 —— 它只是你给自己
/// 加的额外练习。id 与内置节点重复的个人节点会被忽略，避免出现两个同名关卡。
///
/// 同一个文件夹里扫出的**非节点文档**（笔记、业务背景）不走这里 —— 它们是
/// SOP 阶段 0 的输入源物料，由 [ResourceScanner.materials] 提供给
/// `materialsProvider`。一个文件夹养两种东西，用途不同，桶也分开。
///
/// 注意这里**不**读数据文件夹：那是 APP 自己的数据（打卡/行动卡片），
/// 与学习资源是两件事。
///
/// 节点数据属于静态参考内容（几乎不变），因此这里带一层内存缓存，
/// 避免每次进节点列表都发 15+ 次读取请求。
class TrackRepository {
  /// 个性化资源扫描器；store 为 null = 未设置 → 只有内置标准路线
  final ResourceScanner scanner;

  /// trackId → 节点列表
  final Map<String, List<Node>> _nodeCache = {};

  /// trackId → Track
  final Map<String, Track> _trackCache = {};

  TrackRepository(this.scanner);

  /// 未设置个性化资源文件夹时的仓库 —— 只有内置标准路线
  TrackRepository.empty() : scanner = ResourceScanner(null);

  /// 清空缓存（下拉刷新时调用）
  void invalidate([String? trackId]) {
    scanner.invalidate();
    if (trackId == null) {
      _nodeCache.clear();
      _trackCache.clear();
    } else {
      _nodeCache.remove(trackId);
      _trackCache.remove(trackId);
    }
  }

  /// 加载全部可用的 track
  Future<List<Track>> loadAll() async {
    final tracks = <Track>[];
    for (final descriptor in TrackCatalog.all) {
      try {
        tracks.add(await loadTrack(descriptor.id));
      } on FileStoreException {
        // 某个 track 的数据缺失不该让整页失败
        continue;
      }
    }
    return tracks;
  }

  /// 加载单个 track（含按 order 排序的节点 id 列表）
  Future<Track> loadTrack(String trackId) async {
    final cached = _trackCache[trackId];
    if (cached != null) return cached;

    final nodes = await loadNodes(trackId);
    final descriptor = TrackCatalog.byId(trackId);

    final track = Track(
      id: descriptor.id,
      title: descriptor.title,
      description: descriptor.subtitle,
      slot: _slotFor(descriptor.rotationSlotLabel),
      remotePath: AppPaths.trackDir(trackId),
      phases: descriptor.phases
          .map((p) => TrackPhase(
                number: p.number,
                name: p.name,
                startPercent: p.startPercent,
                endPercent: p.endPercent,
              ))
          .toList(),
      nodeIds: nodes
          .where((n) => !n.isBonus && !n.isSupplementary)
          .map((n) => n.id)
          .toList(),
    );

    _trackCache[trackId] = track;
    return track;
  }

  /// 加载某 track 的全部节点
  ///
  /// 顺序：内置主线（按 order）→ 内置 Bonus → 个性化补充关（按 order）。
  ///
  /// 个性化资源文件夹里的节点由 [ResourceScanner] 递归扫出；解析不出 `id`
  /// 的 YAML（README、配置、无关文档）被自然过滤掉，与内置节点重名的也会被
  /// 丢掉。扫描失败或一个都没扫到都不影响内置路线 —— 补充本来就是可有可无的。
  Future<List<Node>> loadNodes(String trackId) async {
    final cached = _nodeCache[trackId];
    if (cached != null) return cached;

    final nodes = List<Node>.of(await StandardCurriculum.loadNodes(trackId));
    final builtinIds = nodes.map((n) => n.id).toSet();

    try {
      for (final node in (await scanner.scan()).nodes) {
        if (!builtinIds.add(node.id)) continue; // 与内置重名 → 忽略
        nodes.add(node.copyWith(isSupplementary: true));
      }
    } catch (_) {
      // 个人文件夹扫不动不该影响内置路线
    }

    nodes.sort((a, b) {
      final byKind = _kindOf(a).compareTo(_kindOf(b));
      return byKind != 0 ? byKind : a.order.compareTo(b.order);
    });

    _nodeCache[trackId] = nodes;
    return nodes;
  }

  /// 排序分组：0 = 内置主线，1 = 内置 Bonus，2 = 个性化补充
  static int _kindOf(Node n) {
    if (n.isSupplementary) return 2;
    return n.isBonus ? 1 : 0;
  }

  /// 加载单个节点
  Future<Node?> loadNode(String trackId, String nodeId) async {
    final nodes = await loadNodes(trackId);
    for (final n in nodes) {
      if (n.id == nodeId) return n;
    }
    return null;
  }

  /// 计算今日应当攻坚的节点
  ///
  /// 规则：第一个「前置已全部通过」且「自身未通过」的主线节点。
  /// 若全部主线已通过，则返回 Bonus 节点。补充关不参与自动选关 ——
  /// 想练哪一关由用户自己在路线页点进去。
  Node? nextNode(List<Node> nodes, Set<String> passedIds) {
    for (final node in nodes.where((n) => !n.isBonus && !n.isSupplementary)) {
      if (passedIds.contains(node.id)) continue;
      if (node.prerequisitesMet(passedIds)) return node;
    }
    for (final node in nodes.where((n) => n.isBonus && !n.isSupplementary)) {
      if (!passedIds.contains(node.id)) return node;
    }
    return null;
  }

  /// 判定某节点是否被锁定（前置未满足）
  bool isLocked(Node node, Set<String> passedIds) =>
      !node.prerequisitesMet(passedIds) && !passedIds.contains(node.id);

  /// 整体进度百分比 —— 只算内置主线，Bonus 与补充关都不计入
  double overallProgress(List<Node> nodes, Set<String> passedIds) {
    final mainline =
        nodes.where((n) => !n.isBonus && !n.isSupplementary).toList();
    if (mainline.isEmpty) return 0;
    final passed = mainline.where((n) => passedIds.contains(n.id)).length;
    return (passed / mainline.length * 100).clamp(0, 100);
  }

  // ------------------------------------------------------------------

  static RotationSlot _slotFor(String label) {
    for (final slot in RotationSlot.values) {
      if (slot.label == label) return slot;
    }
    return RotationSlot.cppBasics;
  }
}
