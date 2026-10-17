import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../../domain/models/node.dart';
import 'standard_curriculum_data.dart';

/// 内置标准课程 —— 业界通用、去个性化的学习路线。
///
/// 这是 APP 的**主干**：打包进 APK/EXE，永远生效，保证开箱即用。
/// 内容以**当前 C++ 标准（C++23/C++26）**为准，不绑定任何行业与业务。
///
/// 个性化从**独立的学习路线文件夹**来（见 `learningRootProvider`）：
/// 用户选定该文件夹后，[TrackRepository] 会递归扫描其中的节点 YAML，
/// 作为补充关**追加在**这条主线之后。与存放打卡数据的「数据文件夹」无关。
class StandardCurriculum {
  StandardCurriculum._();

  /// 内置标准课程只覆盖 cpp 这一条主线；其余 track 一律走本地文件夹。
  static const String cppTrackId = 'cpp';

  /// 加载某 track 的内置标准节点。
  ///
  /// 只有 [cppTrackId] 有内置标准路线；其他 track 返回空列表，
  /// 交给上层判断「本地也没有」并给出空态。
  ///
  /// 内容以内嵌 base64 常量（[cppNodeYamlBase64]）形式打包进 Dart 源码，
  /// 而不是走 `rootBundle` —— 中文项目路径下 asset 目录无法被 Flutter
  /// 打包（manifest 里缺 assets/seed/**），base64 内嵌则彻底规避该问题，
  /// 在测试、Windows、Web 上行为完全一致。
  static Future<List<Node>> loadNodes(String trackId) async {
    if (trackId != cppTrackId) return const [];

    final nodes = <Node>[];
    for (final b64 in cppNodeYamlBase64) {
      try {
        final raw = utf8.decode(base64Decode(b64));
        final parsed = loadYaml(raw);
        if (parsed is! Map) continue;
        final node = Node.fromYaml(parsed);
        if (node.id.isNotEmpty) nodes.add(node);
      } catch (_) {
        // 单个内置节点损坏不应拖垮整条路线
        continue;
      }
    }

    nodes.sort((a, b) {
      if (a.isBonus != b.isBonus) return a.isBonus ? 1 : -1;
      return a.order.compareTo(b.order);
    });
    return nodes;
  }
}
