import '../../domain/enums/app_enums.dart';

/// 预设服务商清单
///
/// AI 配置页的首要动作是「选一家」而不是「填两个框」——
/// 服务地址与模型名是厂商给定的常量，让用户手打只会多出两个填错的机会。
/// 这里把常见厂商的默认值固化下来；不在这张表里的端点走「自定义」。
///
/// 地址结尾**不写斜杠**，端点由 [AiSettings.chatEndpoint] 按协议拼接：
/// OpenAI 兼容 → `{地址}/chat/completions`，Anthropic 兼容 → `{地址}/v1/messages`。
class AiProviderPreset {
  /// 标识，与设置页的选中状态对应（`custom` 保留给手动填写）
  final String id;

  /// 显示名
  final String name;

  /// 服务地址
  final String baseUrl;

  /// 默认模型名
  final String model;

  final AiProtocol protocol;

  const AiProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.protocol,
  });
}

/// 「自定义」不是预设，但选中态要有个值
const String kCustomProviderId = 'custom';

const List<AiProviderPreset> kAiProviderPresets = [
  AiProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    model: 'deepseek-reasoner',
    protocol: AiProtocol.openai,
  ),
  AiProviderPreset(
    id: 'qwen',
    name: '通义千问',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    model: 'qwen-plus',
    protocol: AiProtocol.openai,
  ),
  AiProviderPreset(
    id: 'kimi',
    name: 'Kimi',
    baseUrl: 'https://api.moonshot.cn/v1',
    model: 'moonshot-v1-8k',
    protocol: AiProtocol.openai,
  ),
  AiProviderPreset(
    id: 'zhipu',
    name: '智谱 GLM',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    model: 'glm-4-plus',
    protocol: AiProtocol.openai,
  ),
  AiProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4o',
    protocol: AiProtocol.openai,
  ),
  AiProviderPreset(
    id: 'claude',
    name: 'Claude',
    baseUrl: 'https://api.anthropic.com',
    model: 'claude-sonnet-5-5',
    protocol: AiProtocol.anthropic,
  ),
];

/// 按 id 查预设，查不到返回 null（含 `custom`）
AiProviderPreset? presetById(String id) {
  for (final p in kAiProviderPresets) {
    if (p.id == id) return p;
  }
  return null;
}

/// 反向匹配：已存的地址 + 模型命中了哪家预设。
///
/// 老用户存的是 DeepSeek 默认值，进来应该直接高亮在 DeepSeek 上，
/// 而不是显示成「自定义」。匹配不上就老老实实回到自定义。
String matchPresetId(String baseUrl, String model) {
  final url = _trimSlash(baseUrl.trim());
  final name = model.trim();
  for (final p in kAiProviderPresets) {
    if (_trimSlash(p.baseUrl) == url && p.model == name) return p.id;
  }
  return kCustomProviderId;
}

String _trimSlash(String s) {
  var v = s;
  while (v.endsWith('/')) {
    v = v.substring(0, v.length - 1);
  }
  return v;
}
