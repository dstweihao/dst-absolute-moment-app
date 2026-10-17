import 'package:absolute_moment_app/data/ai/prompts/stage_prompts.dart';
import 'package:absolute_moment_app/domain/enums/app_enums.dart';
import 'package:absolute_moment_app/domain/models/checkin.dart';
import 'package:absolute_moment_app/domain/models/source_material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 审校门的两条提示词路径
///
/// 首轮要给足上下文（输入源 + 节点 + 答案）；后续轮**只发最新答案** ——
/// 输入源和节点上一条消息里还在，重复发送既费钱，也会把模型的注意力
/// 从「答案哪里变了」引开。
void main() {
  const material = SourceMaterial(
    path: '/res/业务背景.md',
    name: '业务背景',
    content: '电商订单系统，日单量 200 万。',
  );

  test('首轮 user() 带上输入源与阶段内容', () {
    const draft = Checkin(
      date: '2026-10-01',
      background: '我负责其中的连接池。',
      userAnswer: '连接池是共享资源，所以要加锁。',
    );

    final prompt = StagePrompts.user(
      SopStageType.questioning,
      node: null,
      draft: draft,
      materials: const [material],
    );

    expect(prompt, contains('【本次输入源】'));
    expect(prompt, contains('电商订单系统，日单量 200 万。'));
    expect(prompt, contains('我负责其中的连接池。'));
    expect(prompt, contains('【阶段① 诘问】'));
    expect(prompt, contains('连接池是共享资源，所以要加锁。'));
  });

  test('后续轮 userFollowUp() 只带最新答案，不重发输入源', () {
    const draft = Checkin(
      date: '2026-10-01',
      background: '我负责其中的连接池。',
      userAnswer: '改过了：锁的粒度应该落在连接上，不是整个池。',
    );

    final followUp = StagePrompts.userFollowUp(SopStageType.questioning, draft);

    expect(followUp, contains('最新版本如下'));
    expect(followUp, contains('锁的粒度应该落在连接上'));
    // 输入源不再重复 —— 首轮那条消息里还在上下文里
    expect(followUp, isNot(contains('【本次输入源】')));
    expect(followUp, isNot(contains('电商订单系统')));
  });

  test('后续轮带的是「当前」答案 —— 用户改了什么，AI 就该看到什么', () {
    const before = Checkin(date: '2026-10-01', userAnswer: '加锁就行。');
    const after = Checkin(date: '2026-10-01', userAnswer: '加锁不够，还要防重入。');

    expect(StagePrompts.userFollowUp(SopStageType.questioning, before),
        contains('加锁就行'));
    expect(StagePrompts.userFollowUp(SopStageType.questioning, after),
        contains('加锁不够，还要防重入'));
    expect(StagePrompts.userFollowUp(SopStageType.questioning, after),
        isNot(contains('加锁就行。')));
  });

  test('每个允许 AI 的阶段都有各自的上下文块', () {
    const draft = Checkin(
      date: '2026-10-01',
      userAnswer: '答案',
      weakestAssumption: '假设',
      businessTranslation: '翻译',
    );

    for (final stage in SopStageType.values.where((s) => s.allowsAi)) {
      expect(
        StagePrompts.userFollowUp(stage, draft),
        contains(stage.label),
        reason: '${stage.label} 的后续轮必须带上自己的阶段标记',
      );
    }
  });
}
