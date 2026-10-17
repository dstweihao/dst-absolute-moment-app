import 'package:yaml/yaml.dart';

/// Markdown + YAML 头部 的解析与生成
///
/// 文件形态：
/// ```
/// ---
/// date: 2026-09-29
/// difficulty: 5
/// ---
///
/// # 正文
/// ```
///
/// `yaml` 包只能解析不能生成，因此下方自实现了一个精简 YAML 生成器，
/// 仅覆盖本 APP 需要的类型：标量、标量列表、一层嵌套映射、映射列表。
///
/// **往返一致性是本类最重要的契约** —— `parse(compose(x)) == x` 必须恒成立，
/// 单元测试对此有强覆盖。
class Frontmatter {
  /// 解析出的头部数据
  final Map<String, dynamic> data;

  /// 分隔符之后的正文
  final String body;

  const Frontmatter({required this.data, required this.body});

  /// 分隔符
  static const String delimiter = '---';

  /// 解析一个 Markdown 文件。
  ///
  /// 容错策略：无头部、头部格式错误、YAML 语法错误 —— 一律不抛异常，
  /// 而是把整个内容当作正文返回，data 为空。
  /// 因为云端文件可能被用户在记事本里手工编辑出错，APP 不能因此崩溃。
  static Frontmatter parse(String markdown) {
    final text = markdown.replaceAll('\r\n', '\n');

    // 必须以 --- 开头（允许前置 BOM 或空行）
    final trimmedStart = text.trimLeft();
    if (!trimmedStart.startsWith(delimiter)) {
      return Frontmatter(data: const {}, body: text);
    }

    final offset = text.length - trimmedStart.length;
    final afterOpen = trimmedStart.substring(delimiter.length);

    // 找结束分隔符：必须独占一行
    final closeIndex = _findClosingDelimiter(afterOpen);
    if (closeIndex < 0) {
      // 只有开头没有结尾，视为无头部
      return Frontmatter(data: const {}, body: text);
    }

    final headerRaw = afterOpen.substring(0, closeIndex).trim();
    if (headerRaw.isEmpty) {
      return Frontmatter(data: const {}, body: text);
    }

    Map<String, dynamic> parsed;
    try {
      final loaded = loadYaml(headerRaw);
      parsed = _normalizeMap(loaded);
    } catch (_) {
      // YAML 语法错误 —— 不崩溃，整篇当正文
      return Frontmatter(data: const {}, body: text);
    }

    final bodyStart = closeIndex + delimiter.length +
        (afterOpen.length > closeIndex + delimiter.length &&
                afterOpen[closeIndex + delimiter.length] == '\n'
            ? 1
            : 0);
    final body = afterOpen.substring(bodyStart.clamp(0, afterOpen.length));

    // offset 目前只用于定位，此处正文从 afterOpen 内部切片即可
    assert(offset >= 0);
    return Frontmatter(data: parsed, body: body.trimLeft());
  }

  /// 在 open 之后的文本里找独占一行的 `---`，返回其起始下标（相对 open 之后）
  static int _findClosingDelimiter(String afterOpen) {
    // 跳过紧跟开头的换行
    var i = 0;
    if (i < afterOpen.length && afterOpen[i] == '\n') i++;

    while (i < afterOpen.length) {
      final lineStart = i;
      final lineEnd = afterOpen.indexOf('\n', lineStart);
      final line = lineEnd < 0
          ? afterOpen.substring(lineStart)
          : afterOpen.substring(lineStart, lineEnd);

      if (line.trimRight() == delimiter) {
        return lineStart;
      }
      if (lineEnd < 0) break;
      i = lineEnd + 1;
    }
    return -1;
  }

  /// YamlMap / YamlList → 普通 Map / List
  static Map<String, dynamic> _normalizeMap(dynamic loaded) {
    if (loaded is! Map) return const {};
    final result = <String, dynamic>{};
    for (final entry in loaded.entries) {
      result[entry.key.toString()] = _normalizeValue(entry.value);
    }
    return result;
  }

  static dynamic _normalizeValue(dynamic v) {
    if (v is Map) {
      final m = <String, dynamic>{};
      for (final e in v.entries) {
        m[e.key.toString()] = _normalizeValue(e.value);
      }
      return m;
    }
    if (v is List) {
      return v.map(_normalizeValue).toList();
    }
    return v;
  }

  /// 组装为完整的 Markdown 文本
  String compose() {
    final header = dumpYaml(data);
    if (header.isEmpty) return body;
    return '$delimiter\n$header$delimiter\n\n$body';
  }

  static String composeWith(Map<String, dynamic> data, String body) =>
      Frontmatter(data: data, body: body).compose();

  // ------------------------------------------------------------------
  // 精简 YAML 生成器
  // ------------------------------------------------------------------

  /// 将 Map 生成为 YAML 文本（除顶层外每层缩进 2 空格）
  static String dumpYaml(Map<String, dynamic> map) {
    final buf = StringBuffer();
    _writeMap(buf, map, 0);
    return buf.toString();
  }

  static void _writeMap(StringBuffer buf, Map map, int indent) {
    final pad = '  ' * indent;
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value == null) continue;

      if (value is Map) {
        if (value.isEmpty) {
          buf.writeln('$pad$key: {}');
        } else {
          buf.writeln('$pad$key:');
          _writeMap(buf, value, indent + 1);
        }
      } else if (value is List) {
        if (value.isEmpty) {
          buf.writeln('$pad$key: []');
        } else if (value.first is Map) {
          buf.writeln('$pad$key:');
          for (final item in value) {
            if (item is! Map || item.isEmpty) continue;
            var first = true;
            for (final e in item.entries) {
              if (e.value == null) continue;
              final prefix = first ? '$pad  - ' : '$pad    ';
              buf.writeln('$prefix${e.key}: ${_scalar(e.value)}');
              first = false;
            }
          }
        } else {
          buf.writeln('$pad$key:');
          for (final item in value) {
            buf.writeln('$pad  - ${_scalar(item)}');
          }
        }
      } else {
        buf.writeln('$pad$key: ${_scalar(value)}');
      }
    }
  }

  /// 标量序列化：字符串按需加引号，数字/布尔裸写
  static String _scalar(dynamic v) {
    if (v == null) return 'null';
    if (v is num || v is bool) return v.toString();
    final s = v.toString();
    return _quoteIfNeeded(s);
  }

  /// 判断字符串是否必须加引号
  static String _quoteIfNeeded(String s) {
    if (s.isEmpty) return "''";

    // 需要引号的情形
    final needsQuote = s.contains(':') ||
        s.contains('#') ||
        s.contains('\n') ||
        s.contains('"') ||
        s.contains("'") ||
        s.startsWith(' ') ||
        s.endsWith(' ') ||
        s.startsWith('-') ||
        s.startsWith('[') ||
        s.startsWith('{') ||
        s.startsWith('*') ||
        s.startsWith('&') ||
        s.startsWith('!') ||
        s.startsWith('%') ||
        s.startsWith('@') ||
        s.startsWith('`') ||
        _looksLikeNumberOrBool(s);

    if (!needsQuote) return s;

    // 含单引号则用双引号并转义
    if (s.contains("'")) {
      final escaped = s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      return '"$escaped"';
    }
    // YAML 单引号内需把 ' 写成 ''
    return "'$s'";
  }

  /// 形如 123 / 1.5 / true / null 的字符串必须加引号，否则会被解析成非字符串
  static bool _looksLikeNumberOrBool(String s) {
    final lower = s.toLowerCase();
    if (lower == 'true' || lower == 'false' || lower == 'null' ||
        lower == 'yes' || lower == 'no' || lower == 'on' || lower == 'off') {
      return true;
    }
    if (num.tryParse(s) != null) return true;
    return false;
  }
}
