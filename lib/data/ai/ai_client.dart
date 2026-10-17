enum AiRole {
  system,
  user,
  assistant;

  String get wireName => name;
}

class AiMessage {
  final AiRole role;
  final String content;

  const AiMessage(this.role, this.content);

  const AiMessage.system(this.content) : role = AiRole.system;
  const AiMessage.user(this.content) : role = AiRole.user;
  const AiMessage.assistant(this.content) : role = AiRole.assistant;

  @override
  String toString() => 'AiMessage(${role.name}: ${content.length} chars)';
}

/// 不同错误给用户的指引完全不同
enum AiErrorKind {
  notConfigured,
  network,
  unauthorized,
  modelNotFound,
  rateLimited,
  badRequest,
  contentFilter,
  server,
  malformedResponse,
  cancelled,
  unknown;

  String get userMessage => switch (this) {
        AiErrorKind.notConfigured => 'AI 未配置 —— 请到「设置 → AI 配置」填写服务地址、模型与 API Key',
        AiErrorKind.network => 'AI 服务连接失败，请检查网络',
        AiErrorKind.unauthorized => 'API Key 无效或无权限，请检查密钥是否填写正确',
        AiErrorKind.modelNotFound => '找不到该模型 —— 请确认服务地址与模型名称匹配',
        AiErrorKind.rateLimited => '调用过于频繁或余额不足，请稍后重试',
        AiErrorKind.badRequest => '请求被拒绝 —— 多半是模型名不被该平台支持',
        AiErrorKind.contentFilter => '输入内容包含敏感词或触发了安全合规审查，已被拦截。请修改后重新提问',
        AiErrorKind.server => 'AI 服务暂时不可用，请稍后重试',
        AiErrorKind.malformedResponse => 'AI 返回内容无法解析',
        AiErrorKind.cancelled => '已取消',
        AiErrorKind.unknown => 'AI 调用发生未知错误',
      };

  bool get isRetryable => switch (this) {
        AiErrorKind.network ||
        AiErrorKind.rateLimited ||
        AiErrorKind.server =>
          true,
        _ => false,
      };

  /// AI 是增强不是依赖：除用户主动取消外，任何失败都只降级为自评，不阻断 SOP
  bool get shouldDegradeGracefully => this != AiErrorKind.cancelled;
}

class AiException implements Exception {
  final AiErrorKind kind;
  final String detail;
  final int? statusCode;

  const AiException(this.kind, {this.detail = '', this.statusCode});

  String get message => kind.userMessage;

  @override
  String toString() => 'AiException(${kind.name}'
      '${statusCode != null ? ' HTTP $statusCode' : ''}'
      '${detail.isNotEmpty ? ': $detail' : ''})';
}

class AiChunk {
  final String delta;
  final bool isDone;

  const AiChunk(this.delta, {this.isDone = false});

  static const AiChunk done = AiChunk('', isDone: true);
}

/// 协议无关的 AI 客户端
///
/// 两个实现：
/// - [OpenAiClient] 走 `POST {base_url}/chat/completions`，覆盖 DeepSeek / Kimi / GLM / 通义 / OpenAI
/// - [AnthropicClient] 走 `POST {base_url}/v1/messages`，覆盖 Claude 与 DeepSeek 的 Anthropic 端点
abstract class AiClient {
  /// 失败时抛 [AiException]，调用方据 `kind.shouldDegradeGracefully`
  /// 决定是降级还是提示用户。
  Stream<AiChunk> streamChat(List<AiMessage> messages);

  /// 内部消费流并拼接，用于「测试连接」
  Future<String> chat(List<AiMessage> messages);

  /// 发一条极短请求验证配置可用
  Future<void> testConnection();

  void cancel();

  void dispose();
}
