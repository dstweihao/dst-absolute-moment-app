import 'package:yaml/yaml.dart';

import '../../domain/models/source_material.dart';
import '../../domain/models/node.dart';
import '../storage/file_store.dart';

/// 一次递归扫描的结果 —— 同一个文件夹，两个桶
///
/// 分桶是刻意的：节点喂路线，物料喂 SOP 阶段 0。两者都在个性化资源
/// 文件夹里，但**绝不能混着用** —— 把笔记当成关卡会让路线失控，
/// 把练习题当成背景会让 AI 拷问不到点子上。
class ResourceScan {
  /// 能解析成节点的 YAML → 补充关
  final List<Node> nodes;

  /// 其余文档 → 阶段 0 的输入源物料
  final List<SourceMaterial> materials;

  const ResourceScan({this.nodes = const [], this.materials = const []});

  bool get isEmpty => nodes.isEmpty && materials.isEmpty;

  static const ResourceScan empty = ResourceScan();
}

/// 个性化资源文件夹的递归扫描器
///
/// 一次遍历同时产出节点与物料两个桶，结果整体缓存 —— 分成两个仓库各扫
/// 一遍会让 WebDAV 这类远程盘付双倍往返。
///
/// 目录结构**任意**：从根开始广度优先，任意嵌套都能用。设深度与目录数上限，
/// 避免用户误把整个网盘根/用户主目录指过来时陷入长时间扫描；命中上限会带着
/// 已收集到的结果返回，不报错。
class ResourceScanner {
  /// 个性化资源存储；null = 未设置 → 两个桶都是空的
  final FileStore? store;

  ResourceScanner(this.store);

  static const int maxDepth = 8;
  static const int maxDirs = 400;

  /// 物料条数上限 —— 超过这个数说明用户指的是一个资料库而不是一个文件夹，
  /// 全塞进提示词没有意义
  static const int maxMaterials = 50;

  ResourceScan? _cache;

  /// 清空缓存（换文件夹、下拉刷新时调用）
  void invalidate() => _cache = null;

  Future<ResourceScan> scan() async {
    final cached = _cache;
    if (cached != null) return cached;

    final store = this.store;
    if (store == null) return _cache = ResourceScan.empty;

    return _cache = await _walk(store);
  }

  // ------------------------------------------------------------------

  Future<ResourceScan> _walk(FileStore store) async {
    final nodes = <Node>[];
    final materials = <SourceMaterial>[];
    final visited = <String>{'/0'};

    // 广度优先：(逻辑路径, 深度)
    final queue = <(String, int)>[('/', 0)];
    var dirsSeen = 0;

    while (queue.isNotEmpty && dirsSeen < maxDirs) {
      final (dir, depth) = queue.removeAt(0);
      dirsSeen++;

      List<StoreEntry> entries;
      try {
        entries = await store.list(dir);
      } on FileStoreException {
        // 单个目录读不了不该让整次扫描失败
        continue;
      } catch (_) {
        continue;
      }

      for (final entry in entries) {
        if (entry.isDirectory) {
          // 跳过隐藏目录（.git、.trash 之类）
          if (depth < maxDepth &&
              !entry.name.startsWith('.') &&
              visited.add('${entry.path}/$depth')) {
            queue.add((entry.path, depth + 1));
          }
          continue;
        }

        final name = entry.name.toLowerCase();

        // ---- 节点桶：YAML ----
        if (name.endsWith('.yaml') || name.endsWith('.yml')) {
          try {
            final node = _parseNode(await store.read(entry.path));
            if (node != null) nodes.add(node);
          } catch (_) {
            // 单个 YAML 格式错误不影响其他节点
          }
          continue;
        }

        // ---- 物料桶：文档 ----
        if (materials.length >= maxMaterials) continue;
        if (!_isMaterialFile(name)) continue;

        try {
          materials.add(
            SourceMaterial(
              path: entry.path,
              name: _displayName(entry.name),
              // 整篇读入。截断过的背景会在句子中间断掉，
              // AI 据此追问出来的问题全是偏的。
              content: await store.read(entry.path),
            ),
          );
        } catch (_) {
          // 单份文档读不了不影响其他物料
        }
      }
    }

    materials.sort((a, b) => a.name.compareTo(b.name));
    return ResourceScan(nodes: nodes, materials: materials);
  }

  /// 哪些扩展名算「物料」。
  ///
  /// 刻意只认纯文本：二进制文档（.docx / .pdf）读出来是乱码，
  /// 塞进提示词只会污染上下文。要传背景就导出成 Markdown。
  static bool _isMaterialFile(String lowerName) =>
      lowerName.endsWith('.md') ||
      lowerName.endsWith('.markdown') ||
      lowerName.endsWith('.txt');

  /// `/notes/架构笔记.md` → `架构笔记`
  static String _displayName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  /// 解析单个节点 YAML
  static Node? _parseNode(String raw) {
    final loaded = loadYaml(raw);
    if (loaded is! Map) return null;
    final node = Node.fromYaml(loaded);
    return node.id.isEmpty ? null : node;
  }
}
