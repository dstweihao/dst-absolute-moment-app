import 'ai_client.dart';
import 'base_ai_client.dart';

/// OpenAI 兼容协议客户端
///
/// 端点：`POST {base_url}/chat/completions`
/// 覆盖：DeepSeek、Kimi（月之暗面）、智谱 GLM、通义千问、OpenAI、以及绝大多数
/// 国产大模型平台 —— 它们都提供 OpenAI 兼容接口。
class OpenAiClient extends BaseAiClient {
  OpenAiClient({
    required super.settings,
    required super.apiKey,
    super.httpClient,
  });

  @override
  Uri buildUri() => Uri.parse(settings.chatEndpoint);

  @override
  Map<String, String> buildHeaders() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  @override
  Map<String, dynamic> buildBody(
    List<AiMessage> messages, {
    required bool stream,
  }) {
    final body = <String, dynamic>{
      'model': settings.model,
      'messages': messages
          .map((m) => {
                'role': m.role.wireName,
                'content': m.content,
              })
          .toList(),
      'stream': stream,
      'temperature': settings.temperature,
      'max_tokens': settings.maxTokens,
    };

    // 部分平台支持推理档位（如 DeepSeek 的 low/high/max）。
    // 不支持的平台会忽略未知字段，但为稳妥起见留空则不传。
    final effort = settings.reasoningEffort;
    if (effort != null && effort.isNotEmpty) {
      body['reasoning_effort'] = effort;
    }

    return body;
  }

  @override
  String? extractDelta(Map<String, dynamic> event) {
    final choices = event['choices'];
    if (choices is! List || choices.isEmpty) return null;

    final first = choices.first;
    if (first is! Map) return null;

    // 流式：delta.content
    final delta = first['delta'];
    if (delta is Map) {
      final content = delta['content'];
      if (content is String && content.isNotEmpty) return content;

      // 部分平台的推理模型把思考过程放在 reasoning_content，
      // 这不是我们想要的正文，跳过。
    }

    // 非流式兜底：message.content
    final message = first['message'];
    if (message is Map) {
      final content = message['content'];
      if (content is String) return content;
    }

    return null;
  }

  @override
  bool isDoneEvent(Map<String, dynamic> event) {
    final choices = event['choices'];
    if (choices is! List || choices.isEmpty) return false;
    final first = choices.first;
    if (first is! Map) return false;
    return first['finish_reason'] != null;
  }

  @override
  String extractFullText(Map<String, dynamic> response) {
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final first = choices.first;
    if (first is! Map) return '';
    final message = first['message'];
    if (message is! Map) return '';
    return (message['content'] ?? '').toString();
  }

  @override
  String? extractServerError(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map) {
      final msg = error['message'];
      if (msg != null) return msg.toString();
    }
    if (error is String) return error;
    final msg = body['message'];
    return msg?.toString();
  }
}
