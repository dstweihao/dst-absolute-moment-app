import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/ai_settings.dart';
import 'ai_client.dart';
import 'sensitive_content_guard.dart';
import 'sse_parser.dart';

/// AI 客户端公共实现
///
/// 把 HTTP 发送、SSE 分帧、错误映射、取消等协议无关的逻辑收在一处，
/// 子类只需实现五个协议相关的方法。
abstract class BaseAiClient implements AiClient {
  final AiSettings settings;
  final String apiKey;
  final http.Client _http;
  final bool _ownsClient;

  /// 当前进行中的请求，用于 cancel()
  http.Client? _activeRequestClient;
  bool _cancelled = false;

  BaseAiClient({
    required this.settings,
    required this.apiKey,
    http.Client? httpClient,
  })  : _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  // ------------------------------------------------------------------
  // 子类需要实现的协议细节
  // ------------------------------------------------------------------

  /// 请求端点
  Uri buildUri();

  /// 请求头
  Map<String, String> buildHeaders();

  /// 请求体
  Map<String, dynamic> buildBody(List<AiMessage> messages, {required bool stream});

  /// 从单个流式事件里取出文本增量；非文本事件返回 null
  String? extractDelta(Map<String, dynamic> event);

  /// 该事件是否表示流结束
  bool isDoneEvent(Map<String, dynamic> event);

  /// 从一次性响应里取出完整文本
  String extractFullText(Map<String, dynamic> response);

  /// 从错误响应体里取出服务端给的原因，取不到返回 null
  String? extractServerError(Map<String, dynamic> body);

  // ------------------------------------------------------------------
  // 公共实现
  // ------------------------------------------------------------------

  @override
  Stream<AiChunk> streamChat(List<AiMessage> messages) async* {
    _ensureConfigured();
    _cancelled = false;

    // 前置违禁/敏感词防线：避免敏感词直接冲破网关导致封禁或粗暴断网报错
    final lastUserMsg = messages.where((m) => m.role == AiRole.user).lastOrNull?.content ?? '';
    if (SensitiveContentGuard.isSensitive(lastUserMsg)) {
      throw const AiException(
        AiErrorKind.contentFilter,
        detail: '输入内容包含不当词汇或敏感用语',
      );
    }

    final request = http.Request('POST', buildUri());
    request.headers.addAll(buildHeaders());
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode(buildBody(messages, stream: true));

    final client = http.Client();
    _activeRequestClient = client;

    try {
      final response = await client
          .send(request)
          .timeout(Duration(seconds: settings.timeoutSeconds));

      if (response.statusCode != 200) {
        final bodyBytes = await _collect(response.stream);
        throw _mapHttpError(response.statusCode, bodyBytes);
      }

      final sse = SseParser();
      final decoder = IncrementalUtf8Decoder();

      await for (final bytes in response.stream) {
        if (_cancelled) break;

        for (final payload in sse.addChunk(decoder.add(bytes))) {
          if (payload.trim() == '[DONE]') {
            yield AiChunk.done;
            return;
          }

          Map<String, dynamic> event;
          try {
            final decoded = jsonDecode(payload);
            if (decoded is! Map) continue;
            event = decoded.cast<String, dynamic>();
          } catch (_) {
            // 单条事件解析失败不该中断整条流
            continue;
          }

          if (event.containsKey('error')) {
            final errorMsg = extractServerError(event) ?? '服务商返回错误';
            if (SensitiveContentGuard.isContentFilterError(errorMsg)) {
              throw AiException(AiErrorKind.contentFilter, detail: errorMsg);
            }
            throw AiException(AiErrorKind.server, detail: errorMsg);
          }

          if (isDoneEvent(event)) {
            yield AiChunk.done;
            return;
          }

          final delta = extractDelta(event);
          if (delta != null && delta.isNotEmpty) {
            yield AiChunk(delta);
          }
        }
      }

      // 处理没有以空行收尾的尾部事件
      for (final payload in sse.flush()) {
        if (payload.trim() == '[DONE]') break;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            final delta = extractDelta(decoded.cast<String, dynamic>());
            if (delta != null && delta.isNotEmpty) yield AiChunk(delta);
          }
        } catch (_) {
          // 忽略
        }
      }

      yield AiChunk.done;
    } on TimeoutException {
      throw const AiException(
        AiErrorKind.network,
        detail: '等待响应超时',
      );
    } on AiException {
      rethrow;
    } on http.ClientException catch (e) {
      final isReset = e.message.toLowerCase().contains('reset') ||
          e.message.toLowerCase().contains('abort') ||
          e.message.toLowerCase().contains('closed') ||
          e.message.contains('连接被重置');
      final lastUserMsg = messages.where((m) => m.role == AiRole.user).lastOrNull?.content ?? '';
      if ((isReset || e.message.isNotEmpty) && SensitiveContentGuard.isSensitive(lastUserMsg)) {
        throw const AiException(
          AiErrorKind.contentFilter,
          detail: '输入内容触发了服务商防火墙安全过滤（连接被断开）',
        );
      }
      throw AiException(AiErrorKind.network, detail: e.message);
    } catch (e) {
      throw AiException(AiErrorKind.unknown, detail: e.toString());
    } finally {
      _activeRequestClient = null;
      client.close();
    }
  }

  @override
  Future<String> chat(List<AiMessage> messages) async {
    final buffer = StringBuffer();
    await for (final chunk in streamChat(messages)) {
      if (chunk.isDone) break;
      buffer.write(chunk.delta);
    }
    return buffer.toString();
  }

  @override
  Future<void> testConnection() async {
    _ensureConfigured();
    // 用极短的一次性请求验证 key 与模型名
    final text = await chat(const [
      AiMessage.user('回复"ok"两个字符即可，不要任何其他内容。'),
    ]);
    if (text.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.malformedResponse,
        detail: '连接成功但返回内容为空',
      );
    }
  }

  @override
  void cancel() {
    _cancelled = true;
    _activeRequestClient?.close();
    _activeRequestClient = null;
  }

  @override
  void dispose() {
    cancel();
    if (_ownsClient) _http.close();
  }

  // ------------------------------------------------------------------
  // 辅助
  // ------------------------------------------------------------------

  void _ensureConfigured() {
    if (apiKey.trim().isEmpty) {
      throw const AiException(
        AiErrorKind.notConfigured,
        detail: 'API Key 未填写',
      );
    }
    final problems = settings.validate();
    if (problems.isNotEmpty) {
      throw AiException(
        AiErrorKind.notConfigured,
        detail: problems.join('；'),
      );
    }
  }

  static Future<List<int>> _collect(Stream<List<int>> stream) async {
    final out = <int>[];
    await for (final chunk in stream) {
      out.addAll(chunk);
      // 防御性上限：错误响应不会很大
      if (out.length > 64 * 1024) break;
    }
    return out;
  }

  AiException _mapHttpError(int status, List<int> bodyBytes) {
    String detail = '';
    try {
      final text = utf8.decode(bodyBytes, allowMalformed: true);
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        detail = extractServerError(decoded.cast<String, dynamic>()) ??
            _truncate(text);
      } else {
        detail = _truncate(text);
      }
    } catch (_) {
      detail = _truncate(utf8.decode(bodyBytes, allowMalformed: true));
    }

    if (SensitiveContentGuard.isContentFilterError(detail)) {
      return AiException(AiErrorKind.contentFilter, statusCode: status, detail: detail);
    }

    final kind = switch (status) {
      400 => AiErrorKind.badRequest,
      401 || 403 => AiErrorKind.unauthorized,
      404 => AiErrorKind.modelNotFound,
      429 => AiErrorKind.rateLimited,
      >= 500 && < 600 => AiErrorKind.server,
      _ => AiErrorKind.unknown,
    };

    return AiException(kind, statusCode: status, detail: detail);
  }

  static String _truncate(String s) =>
      s.length > 300 ? '${s.substring(0, 300)}…' : s;
}
