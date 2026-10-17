import 'package:absolute_moment_app/core/constants/app_constants.dart';
import 'package:absolute_moment_app/data/ai/prompts/personas.dart';
import 'package:absolute_moment_app/domain/enums/app_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// 全局去个性化铁律：内置内容（标准路线、轮转槽位、人设）
/// 一律不得携带某个具体业务/行业专属词。
/// 个性化只允许来自用户自己提供的本地资源，绝不预置进标准内容。
void main() {
  const banned = [
    'EMS',
    'BMS',
    '储能',
    '新能源',
    '物联网',
    '工商业',
    '跨界转型',
  ];

  test('轮转槽位与权重键均已去个性化', () {
    final all = <String>[
      ...RotationConfig.rotationQueue,
      ...RotationConfig.defaultWeights.keys,
      ...RotationSlot.values.map((s) => s.label),
    ];
    expect(all, isNotEmpty);
    for (final text in all) {
      for (final word in banned) {
        expect(text.contains(word), false,
            reason: '「$text」不应包含业务专属词「$word」');
      }
    }
  });

  test('拆塔官人设提示词已去个性化', () {
    for (final word in banned) {
      expect(Personas.socraticMasterPrompt.contains(word), false,
          reason: '人设提示词不应包含业务专属词「$word」');
    }
  });
}
