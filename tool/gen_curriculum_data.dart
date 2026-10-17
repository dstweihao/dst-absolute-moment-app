import 'dart:convert';
import 'dart:io';

/// 把 `assets/seed/tracks/cpp/nodes/*.yaml` 内嵌成 base64 常量。
///
/// 不做手工维护的清单 —— 直接读目录并按文件名排序（`00-…` → `14-…` →
/// `bonus-…`），这样增删节点只改 YAML，不会再出现"加了文件忘了登记"。
void main() {
  final base = Directory('assets/seed/tracks/cpp/nodes');
  final files = base
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stderr.writeln('no node yaml found under ${base.path}');
    exitCode = 1;
    return;
  }

  final buf = StringBuffer();
  buf.writeln('// GENERATED FILE — 请勿手改。');
  buf.writeln('// 来源：assets/seed/tracks/cpp/nodes/*.yaml，经 base64/UTF-8 内嵌，');
  buf.writeln('// 规避中文项目路径下 asset 目录无法被打包的问题。');
  buf.writeln('// 重新生成：dart run tool/gen_curriculum_data.dart');
  buf.writeln('library;');
  buf.writeln();
  buf.writeln('/// 内置标准 C++ 路线各节点的 YAML 原文（base64 编码的 UTF-8）。');
  buf.writeln('/// 顺序即学习顺序（与各节点 order 字段一致）。');
  buf.writeln('const List<String> cppNodeYamlBase64 = [');
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    final content = f.readAsStringSync();
    final b64 = base64Encode(utf8.encode(content));
    buf.writeln("  '$b64', // $name");
  }
  buf.writeln('];');
  final out = File('lib/data/seed/standard_curriculum_data.dart');
  out.writeAsStringSync(buf.toString());
  // ignore: avoid_print
  print('wrote ${files.length} nodes -> ${out.path}');
}
