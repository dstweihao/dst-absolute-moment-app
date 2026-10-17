import 'package:absolute_moment_app/data/ai/provider_presets.dart';
import 'package:absolute_moment_app/domain/enums/app_enums.dart';
import 'package:absolute_moment_app/domain/models/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// 预设服务商清单的护栏。
///
/// 这张表的价值就在于「点一下就对」—— 地址写错一个字符，用户点完测连接
/// 才发现，比手打还糟。所以这里把「不能空、不能重、必须能拼出端点」钉死。
void main() {
  test('预设 id 唯一，地址与模型都不为空', () {
    final ids = kAiProviderPresets.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id 重复会让选中态串台');

    for (final p in kAiProviderPresets) {
      expect(p.id, isNotEmpty);
      expect(p.id, isNot(kCustomProviderId), reason: 'custom 是保留值');
      expect(p.name, isNotEmpty);
      expect(p.baseUrl, startsWith('http'), reason: '${p.id} 的地址不是完整 URL');
      expect(p.baseUrl, isNot(endsWith('/')),
          reason: '${p.id} 地址结尾不该带斜杠，端点由 chatEndpoint 拼');
      expect(p.model, isNotEmpty);
    }
  });

  test('每个预设都能拼出一个像样的端点', () {
    for (final p in kAiProviderPresets) {
      final settings = AiSettings(
        enabled: true,
        protocol: p.protocol,
        baseUrl: p.baseUrl,
        model: p.model,
      );
      expect(settings.validate(), isEmpty, reason: '${p.id} 的默认值应能直接通过校验');
      expect(
        settings.chatEndpoint,
        p.protocol == AiProtocol.anthropic
            ? '${p.baseUrl}/v1/messages'
            : '${p.baseUrl}/chat/completions',
      );
    }
  });

  test('首项与内置默认配置一致 —— 老用户进来不会看到「自定义」', () {
    final first = kAiProviderPresets.first;
    expect(first.baseUrl, AiSettings.defaults.baseUrl);
    expect(first.model, AiSettings.defaults.model);
    expect(first.protocol, AiSettings.defaults.protocol);

    expect(
      matchPresetId(AiSettings.defaults.baseUrl, AiSettings.defaults.model),
      first.id,
    );
  });

  test('反向匹配：命中预设带斜杠也认，不命中落回 custom', () {
    for (final p in kAiProviderPresets) {
      expect(matchPresetId('${p.baseUrl}/', p.model), p.id);
      expect(matchPresetId(p.baseUrl, p.model), p.id);
    }
    expect(matchPresetId('https://example.com/v1', 'some-model'),
        kCustomProviderId);
    // 地址对上但模型不是预设里的，也算自定义 —— 他显然自己改过
    expect(matchPresetId(kAiProviderPresets.first.baseUrl, 'my-finetune'),
        kCustomProviderId);
  });
}
