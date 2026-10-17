import 'dart:convert';

/// Server-Sent Events 解析器
///
/// OpenAI 与 Anthropic 的流式接口都用 SSE，但事件体格式不同。
/// 本类只负责**分帧**（把字节流切成一条条 `data:` 负载），
/// 具体 JSON 结构由各自的客户端解释。
///
/// 分帧规则（依据 SSE 规范）：
/// - 以空行分隔事件
/// - 每个事件由若干 `field: value` 行组成
/// - 只关心 `data` 字段，多行 data 用换行拼接
class SseParser {
  final StringBuffer _buffer = StringBuffer();

  /// 喂入一个 UTF-8 解码后的片段，返回本次能解析出的完整 data 负载
  List<String> addChunk(String chunk) {
    _buffer.write(chunk);
    final text = _buffer.toString();

    final payloads = <String>[];

    // 事件以空行分隔（兼容 \n\n 与 \r\n\r\n）
    var searchFrom = 0;
    while (true) {
      final sep = _findEventSeparator(text, searchFrom);
      if (sep == null) break;

      final rawEvent = text.substring(searchFrom, sep.start);
      final payload = _extractData(rawEvent);
      if (payload != null) payloads.add(payload);

      searchFrom = sep.end;
    }

    // 保留未完成的尾部
    if (searchFrom > 0) {
      _buffer
        ..clear()
        ..write(text.substring(searchFrom));
    }

    return payloads;
  }

  /// 流结束时调用，处理没有以空行收尾的最后一个事件
  List<String> flush() {
    final text = _buffer.toString();
    _buffer.clear();
    if (text.trim().isEmpty) return const [];

    final payload = _extractData(text);
    return payload == null ? const [] : [payload];
  }

  /// 找下一个事件分隔符，返回其起止位置
  static _Sep? _findEventSeparator(String text, int from) {
    final lf = text.indexOf('\n\n', from);
    final crlf = text.indexOf('\r\n\r\n', from);

    if (lf < 0 && crlf < 0) return null;

    if (lf >= 0 && (crlf < 0 || lf < crlf)) {
      return _Sep(lf, lf + 2);
    }
    return _Sep(crlf, crlf + 4);
  }

  /// 从一个事件块中提取 data 字段内容
  static String? _extractData(String rawEvent) {
    final lines = rawEvent.split(RegExp(r'\r?\n'));
    final dataLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('data:')) {
        var value = line.substring(5);
        // SSE 规范：冒号后可选一个空格
        if (value.startsWith(' ')) value = value.substring(1);
        dataLines.add(value);
      }
    }

    if (dataLines.isEmpty) return null;
    return dataLines.join('\n');
  }

  /// 尝试把字节片段按 UTF-8 解码（容忍跨块截断的多字节字符）
  static String decode(List<int> bytes) =>
      utf8.decode(bytes, allowMalformed: true);
}

class _Sep {
  final int start;
  final int end;
  const _Sep(this.start, this.end);
}

/// 跨块的 UTF-8 解码器
///
/// 网络分块可能把一个中文字符切成两半，直接 `utf8.decode` 会产生乱码。
/// 本类缓存不完整的尾部字节，等下一块到达再拼接。
class IncrementalUtf8Decoder {
  final List<int> _pending = [];

  /// 喂入字节，返回本次能完整解码的字符串
  String add(List<int> bytes) {
    if (bytes.isEmpty) return '';

    final all = <int>[..._pending, ...bytes];
    _pending.clear();

    // 从尾部向前找最后一个完整的 UTF-8 字符边界。
    // 一个多字节序列最长 4 字节，因此最多向前看 4 个字节即可定位其前导字节。
    var cut = all.length;
    final tailStart = all.length - 4 > 0 ? all.length - 4 : 0;
    for (var i = all.length - 1; i >= tailStart; i--) {
      final byte = all[i];
      if (byte & 0x80 == 0) {
        // ASCII 字符，必然是完整边界
        break;
      }
      if (byte & 0xC0 == 0xC0) {
        // 前导字节：它声明的长度与「从 i 到末尾」的可用字节数比较
        final need = _sequenceLength(byte);
        if (all.length - i < need) {
          cut = i; // 不完整，从这里截断留作下次拼接
        }
        break;
      }
      // 续接字节（10xxxxxx），继续向前找它的前导字节
    }

    if (cut < all.length) {
      _pending.addAll(all.sublist(cut));
    }

    return utf8.decode(all.sublist(0, cut), allowMalformed: true);
  }

  /// 流结束时冲刷剩余字节
  String flush() {
    if (_pending.isEmpty) return '';
    final text = utf8.decode(_pending, allowMalformed: true);
    _pending.clear();
    return text;
  }

  static int _sequenceLength(int leadByte) {
    if (leadByte & 0x80 == 0) return 1;
    if (leadByte & 0xE0 == 0xC0) return 2;
    if (leadByte & 0xF0 == 0xE0) return 3;
    if (leadByte & 0xF8 == 0xF0) return 4;
    return 1;
  }
}
