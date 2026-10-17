/// 数据路径常量
///
/// 这里的路径都是**相对于存储根目录**的逻辑路径。根目录由用户在设置里选定
/// （例如坚果云同步目录 `C:\我的坚果云`），APP 只负责读写这个文件夹，
/// 同步交给坚果云客户端 —— APP 本身不感知"云"的存在。
///
/// ⚠️ 目录名保持英文：既是跨平台安全（部分文件系统对中文路径处理不一致），
/// 也让这些路径在任何同步工具下都不易出问题。
class AppPaths {
  AppPaths._();

  // ------------------------------------------------------------------
  // APP 自己的数据（写）
  // ------------------------------------------------------------------

  /// APP 数据根目录 —— 首次运行时自动创建
  static const String appRoot = '/AbsoluteMoment';

  static const String configFile = '$appRoot/config.yaml';

  static const String checkinsDir = '$appRoot/checkins';

  static const String actionsDir = '$appRoot/actions';
  static const String actionsFile = '$actionsDir/action-cards.md';

  /// 某天的打卡文件路径
  static String checkinFile(String date) => '$checkinsDir/$date.md';

  // ------------------------------------------------------------------
  // 学习路线的约定路径（相对「个性化资源文件夹」，只读）
  // ------------------------------------------------------------------

  /// 个性化资源文件夹里的约定结构。
  ///
  /// ⚠️ 这只是**一种**可选结构，不是要求：`TrackRepository` 会从学习路线
  /// 文件夹根开始递归扫描，任意嵌套的节点 YAML 都能被找到。这些常量仅供
  /// 展示路径与文档引用 —— 路线不再从数据文件夹读取，两者是独立设置。
  static const String tracksRoot = '/tracks';

  /// 某个 track 的约定目录
  static String trackDir(String trackId) => '$tracksRoot/$trackId';

  /// 某个 track 的约定节点目录
  static String nodesDir(String trackId) => '${trackDir(trackId)}/nodes';

  /// 某个 track 的路线图文件
  ///
  /// 约定命名：`tracks/cpp/cpp-roadmap.md`
  static String roadmapFile(String trackId) =>
      '${trackDir(trackId)}/$trackId-roadmap.md';

  /// 判断路径是否为 APP 自己的数据（决定是否可写）
  static bool isAppData(String path) => path.startsWith(appRoot);
}

/// 当前支持的 Track 清单
///
/// 只含 C++ 这条主线。这里的阶段划分是**业界通用、去个性化**的标准路线
/// （兜底元信息）：节点数据优先读本地文件夹，本地没有时回落内置标准课程
/// [StandardCurriculum]。
class TrackCatalog {
  TrackCatalog._();

  static const String cppId = 'cpp';

  static const List<TrackDescriptor> all = [
    TrackDescriptor(
      id: cppId,
      title: 'C++ 高级开发',
      subtitle: '通用标准路线 · 对齐 C++23 / C++26 · 0 → 100%',
      rotationSlotLabel: 'C++基础',
      phases: [
        TrackPhaseDescriptor(1, 'C++ 基础', 0, 43),
        TrackPhaseDescriptor(2, 'C++ 语言核心', 43, 70),
        TrackPhaseDescriptor(3, '并发编程', 70, 78),
        TrackPhaseDescriptor(4, '工程实践', 78, 92),
        TrackPhaseDescriptor(5, '系统编程', 92, 100),
      ],
    ),
  ];

  static TrackDescriptor byId(String id) {
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => all.first,
    );
  }
}

/// Track 元信息
class TrackDescriptor {
  final String id;
  final String title;
  final String subtitle;
  final String rotationSlotLabel;
  final List<TrackPhaseDescriptor> phases;

  const TrackDescriptor({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.rotationSlotLabel,
    required this.phases,
  });
}

/// 阶段元信息
class TrackPhaseDescriptor {
  final int number;
  final String name;
  final double startPercent;
  final double endPercent;

  const TrackPhaseDescriptor(
    this.number,
    this.name,
    this.startPercent,
    this.endPercent,
  );
}
