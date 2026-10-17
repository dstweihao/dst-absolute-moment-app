import '../enums/app_enums.dart';

/// AI 接口配置
///
/// 存储在 `/AbsoluteMoment/config.yaml` 的 `ai:` 段，跨设备同步。
///
/// ⚠️ 安全边界：**API Key 不在此模型中**。
/// config.yaml 会明文同步到坚果云云端，密钥必须单独存
/// `flutter_secure_storage`（设备本地加密），见 `CredentialsStore`。
class AiSettings {
  /// 总开关。关闭后全部阶段走纯自评模式
  final bool enabled;

  /// 协议类型，决定端点拼接方式
  final AiProtocol protocol;

  /// 服务地址，如 `https://api.deepseek.com`
  ///
  /// 末尾斜杠会被自动规范化，用户填不填都行。
  final String baseUrl;

  /// 模型名，如 `deepseek-reasoner`
  final String model;

  final double temperature;
  final int maxTokens;

  /// 推理档位 low | high | max，为空则不传该参数
  ///
  /// 实测：DeepSeek 系列在 high/max 下思考极长，
  /// 日常开发建议 high，出现「只思考不产出」再降到 low。
  final String? reasoningEffort;

  final int timeoutSeconds;

  /// 人设预设标识，目前仅 `socratic_master`（拆塔官）
  final String persona;

  const AiSettings({
    this.enabled = false,
    this.protocol = AiProtocol.openai,
    this.baseUrl = 'https://api.deepseek.com',
    this.model = 'deepseek-reasoner',
    this.temperature = 0.7,
    this.maxTokens = 8192,
    this.reasoningEffort = 'high',
    this.timeoutSeconds = 180,
    this.persona = 'socratic_master',
  });

  /// 默认值即计划中实测验证过的 DeepSeek 配置
  static const AiSettings defaults = AiSettings();

  AiSettings copyWith({
    bool? enabled,
    AiProtocol? protocol,
    String? baseUrl,
    String? model,
    double? temperature,
    int? maxTokens,
    String? reasoningEffort,
    bool clearReasoningEffort = false,
    int? timeoutSeconds,
    String? persona,
  }) {
    return AiSettings(
      enabled: enabled ?? this.enabled,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      reasoningEffort: clearReasoningEffort
          ? null
          : (reasoningEffort ?? this.reasoningEffort),
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      persona: persona ?? this.persona,
    );
  }

  // ---- 端点拼接 ----

  /// 规范化后的 base URL（去掉末尾斜杠）
  String get normalizedBaseUrl {
    var u = baseUrl.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// 补全后的请求端点
  String get chatEndpoint => switch (protocol) {
        AiProtocol.openai => '$normalizedBaseUrl/chat/completions',
        AiProtocol.anthropic => '$normalizedBaseUrl/v1/messages',
      };

  /// 配置是否已达可用状态（不含 key，key 单独校验）
  bool get isConfigured =>
      enabled &&
      normalizedBaseUrl.isNotEmpty &&
      model.trim().isNotEmpty;

  /// 配置完整性检查，返回人类可读的问题列表
  List<String> validate() => [
        if (normalizedBaseUrl.isEmpty) '服务地址未填写',
        if (!normalizedBaseUrl.startsWith('http'))
          '服务地址必须以 http:// 或 https:// 开头',
        if (model.trim().isEmpty) '模型名称未填写',
        if (maxTokens <= 0) '最大输出 token 必须为正数',
        if (timeoutSeconds <= 0) '超时时间必须为正数',
      ];

  factory AiSettings.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return defaults;
    return AiSettings(
      enabled: map['enabled'] == true || map['enabled'] == 'true',
      protocol: AiProtocol.fromString(map['protocol']?.toString()),
      baseUrl: (map['base_url'] ?? defaults.baseUrl).toString(),
      model: (map['model'] ?? defaults.model).toString(),
      temperature: _toDouble(map['temperature'], defaults.temperature),
      maxTokens: _toInt(map['max_tokens'], defaults.maxTokens),
      reasoningEffort: _nullableString(map['reasoning_effort']),
      timeoutSeconds: _toInt(map['timeout_seconds'], defaults.timeoutSeconds),
      persona: (map['persona'] ?? defaults.persona).toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'protocol': protocol.name,
        'base_url': normalizedBaseUrl,
        'model': model,
        'temperature': temperature,
        'max_tokens': maxTokens,
        if (reasoningEffort != null && reasoningEffort!.isNotEmpty)
          'reasoning_effort': reasoningEffort,
        'timeout_seconds': timeoutSeconds,
        'persona': persona,
      };

  static double _toDouble(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static int _toInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static String? _nullableString(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiSettings &&
          other.enabled == enabled &&
          other.protocol == protocol &&
          other.baseUrl == baseUrl &&
          other.model == model &&
          other.temperature == temperature &&
          other.maxTokens == maxTokens &&
          other.reasoningEffort == reasoningEffort &&
          other.timeoutSeconds == timeoutSeconds &&
          other.persona == persona;

  @override
  int get hashCode => Object.hash(
        enabled,
        protocol,
        baseUrl,
        model,
        temperature,
        maxTokens,
        reasoningEffort,
        timeoutSeconds,
        persona,
      );

  @override
  String toString() =>
      'AiSettings(${protocol.name} · $model · enabled=$enabled)';
}
