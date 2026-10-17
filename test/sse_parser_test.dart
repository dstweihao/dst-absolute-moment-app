import 'dart:convert';

import 'package:absolute_moment_app/data/ai/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SseParser 分帧', () {
    test('一次解析多条事件', () {
      final p = SseParser();
      expect(p.addChunk('data: {"a":1}\n\ndata: {"a":2}\n\n'), ['{"a":1}', '{"a":2}']);
    });

    test('跨块拼接', () {
      final p = SseParser();
      expect(p.addChunk('data: {"a":'), isEmpty);
      expect(p.addChunk('1}\n\n'), ['{"a":1}']);
    });

    test('忽略非 data 行', () {
      final p = SseParser();
      expect(p.addChunk('event: message\ndata: hi\n\n'), ['hi']);
    });

    test('多行 data 用换行拼接', () {
      final p = SseParser();
      expect(p.addChunk('data: line1\ndata: line2\n\n'), ['line1\nline2']);
    });

    test('flush 处理无空行收尾的事件', () {
      final p = SseParser();
      p.addChunk('data: tail');
      expect(p.flush(), ['tail']);
      expect(p.flush(), isEmpty);
    });

    test('CRLF 分隔', () {
      final p = SseParser();
      expect(p.addChunk('data: a\r\n\r\n'), ['a']);
    });
  });

  group('IncrementalUtf8Decoder 跨块中文', () {
    test('中文字符被切成两半不丢字', () {
      final d = IncrementalUtf8Decoder();
      final bytes = utf8.encode('你好');
      // 第一字节单独到达，不足以构成完整字符
      expect(d.add(bytes.sublist(0, 1)), '');
      // 剩余字节补齐
      expect(d.add(bytes.sublist(1)), '你好');
    });

    test('完整中文字符不产生替换符', () {
      final d = IncrementalUtf8Decoder();
      expect(d.add(utf8.encode('你好')), '你好');
      expect(d.add(utf8.encode('世界')), '世界');
    });

    test('四字节 emoji 跨块', () {
      final d = IncrementalUtf8Decoder();
      final bytes = utf8.encode('😀');
      expect(d.add(bytes.sublist(0, 2)), '');
      expect(d.add(bytes.sublist(2)), '😀');
    });

    test('ASCII 与中文混合', () {
      final d = IncrementalUtf8Decoder();
      expect(d.add(utf8.encode('abc你')), 'abc你');
    });

    test('flush 在无残留时返回空', () {
      final d = IncrementalUtf8Decoder();
      expect(d.add(utf8.encode('你好')), '你好'); // 完整，无残留
      expect(d.flush(), '');
    });

    test('流被截断时 flush 宽松解码不崩溃', () {
      final d = IncrementalUtf8Decoder();
      final bytes = utf8.encode('你');
      expect(d.add(bytes.sublist(0, 1)), ''); // 不完整字节
      // 截断的字节无法还原，flush 输出替换符而非抛异常
      expect(d.flush(), '�');
    });
  });
}
