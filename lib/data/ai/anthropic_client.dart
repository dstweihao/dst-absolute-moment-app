import 'ai_client.dart';
import 'base_ai_client.dart';

/// Anthropic 兼容协议客户端
///
/// 端点：`POST {base_url}/v1/messages`
/// 覆盖：Claude 官方 API、以及 DeepSeek 提供的 Anthropic 兼容端点
/// （`https://api.deepseek.com/anthropic`）。
///
/// 与 OpenAI 协议的两个关键差异：
/// 1. system 提示词是**顶层参数**，不放在 messages 里
/// 2. 鉴权用 `x-api-key` 头 + 必需的 `anthropic-version`
class AnthropicClient extends BaseAiClient {
  AnthropicClient({
    required super.settings,
    required super.apiKey,
    super.httpClient,
  });

  /// 必须声明，否则服务端拒绝请求
  static const String apiVersion = '2023-06-01';

  @override
  Uri buildUri() => Uri.parse(settings.chatEndpoint);

  @override
  Map<String, String> buildHeaders() => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': apiVersion,
      };

  @override
  Map<String, dynamic> buildBody(
    List<AiMessage> messages, {
    required bool stream,
  }) {
    // system 抽出来单独传
    final systemParts = <String>[];
    final turns = <Map<String, dynamic>>[];

    for (final m in messages) {
      switch (m.role) {
        case AiRole.system:
          systemParts.add(m.content);
          break;
        case AiRole.user:
        case AiRole.assistant:
          turns.add({'role': m.role.wireName, 'content': m.content});
          break;
      }
    }

    final body = <String, dynamic>{
      'model': settings.model,
      'messages': turns,
      'max_tokens': settings.maxTokens,
      'temperature': settings.temperature,
      'stream': stream,
    };

    if (systemParts.isNotEmpty) {
      body['system'] = systemParts.join('\n\n');
    }

    return body;
  }

  @override
  String? extractDelta(Map<String, dynamic> event) {
    final type = event['type']?.toString();

    // 文本增量
    if (type == 'content_block_delta') {
      final delta = event['delta'];
      if (delta is Map) {
        final text = delta['text'];
        if (text is String && text.isNotEmpty) return text;
      }
    }

    return null;
  }

  @override
  bool isDoneEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    return type == 'message_stop';
  }

  @override
  String extractFullText(Map<String, dynamic> response) {
    final content = response['content'];
    if (content is! List) return '';

    final buffer = StringBuffer();
    for (final block in content) {
      if (block is! Map) continue;
      if (block['type']?.toString() != 'text') continue;
      final text = block['text'];
      if (text is String) buffer.write(text);
    }
    return buffer.toString();
  }

  @override
  String? extractServerError(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map) {
      final msg = error['message'];
      if (msg != null) return msg.toString();
    }
    if (error is String) return error;
    return body['message']?.toString();
  }
}
