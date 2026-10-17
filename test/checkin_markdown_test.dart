import 'package:absolute_moment_app/data/serialization/checkin_markdown.dart';
import 'package:absolute_moment_app/domain/models/action_card.dart';
import 'package:absolute_moment_app/domain/models/checkin.dart';
import 'package:flutter_test/flutter_test.dart';

/// 一个字段齐全的打卡记录，用于验证往返不丢任何字段。
Checkin fullCheckin() => Checkin(
      date: '2026-09-29',
      trackId: 'cpp',
      nodeId: 'node-00',
      nodeTitle: '内存模型与指针重塑',
      durationMinutes: 62,
      completed: true,
      aiAssisted: true,
      aiRounds: 4,
      yesterdayFindings: const ['发现一：栈帧随函数返回而消亡', '发现二：变量名是地址的别名', '发现三：指针本身也有地址'],
      recallSkipped: false,
      socraticQuestion: '当我们写下 int a = 10; 时，硬件底层是在虚空造了一个符号，还是往带门牌号的内存抽屉里塞数据？',
      userAnswer: '往内存条抽屉里塞数据',
      weakestAssumption: '变量名 a 就是数据本身',
      counterEvidence: const [
        CounterEvidence(assumed: '变量名 a 就是数据本身', actual: 'a 只是编译器给地址起的别名，运行时不存在'),
        CounterEvidence(assumed: '栈上变量永远存活', actual: '函数执行到右大括号，栈帧立即消亡'),
      ],
      businessTranslation: '给客户用大白话讲清内存模型与指针的关系',
      actionCard: ActionCard(
        id: 'action-2026-09-29',
        sourceDate: '2026-09-29',
        what: '验证采集函数的内存释放路径',
        whenText: '今天 14:00 前',
        criteria: '画出一张释放时序图',
        businessValue: '避免现场内存泄漏事故',
      ),
      difficulty: 5,
    );

void main() {
  test('完整打卡往返不丢字段', () {
    final original = fullCheckin();
    final decoded = CheckinMarkdown.decode(CheckinMarkdown.encode(original));

    expect(decoded.date, original.date);
    expect(decoded.trackId, original.trackId);
    expect(decoded.nodeId, original.nodeId);
    expect(decoded.nodeTitle, original.nodeTitle);
    expect(decoded.durationMinutes, original.durationMinutes);
    expect(decoded.completed, original.completed);
    expect(decoded.aiAssisted, original.aiAssisted);
    expect(decoded.aiRounds, original.aiRounds);
    expect(decoded.yesterdayFindings, original.yesterdayFindings);
    expect(decoded.recallSkipped, original.recallSkipped);
    expect(decoded.socraticQuestion, original.socraticQuestion);
    expect(decoded.userAnswer, original.userAnswer);
    expect(decoded.weakestAssumption, original.weakestAssumption);
    expect(decoded.counterEvidence, original.counterEvidence);
    expect(decoded.businessTranslation, original.businessTranslation);
    expect(decoded.difficulty, original.difficulty);

    final card = decoded.actionCard!;
    expect(card.what, original.actionCard!.what);
    expect(card.whenText, original.actionCard!.whenText);
    expect(card.criteria, original.actionCard!.criteria);
    expect(card.businessValue, original.actionCard!.businessValue);
  });

  test('再编码再解码结果稳定（幂等）', () {
    final markdown1 = CheckinMarkdown.encode(fullCheckin());
    final decoded1 = CheckinMarkdown.decode(markdown1);
    final markdown2 = CheckinMarkdown.encode(decoded1);
    final decoded2 = CheckinMarkdown.decode(markdown2);

    expect(markdown2, markdown1);

    // 关键字段在第二次往返后保持不变
    expect(decoded2.socraticQuestion, decoded1.socraticQuestion);
    expect(decoded2.userAnswer, decoded1.userAnswer);
    expect(decoded2.counterEvidence, decoded1.counterEvidence);
    expect(decoded2.yesterdayFindings, decoded1.yesterdayFindings);
    expect(decoded2.actionCard!.what, decoded1.actionCard!.what);
  });

  test('首次会话跳过昨日提取能往返', () {
    const c = Checkin(date: '2026-09-29', recallSkipped: true);
    final decoded = CheckinMarkdown.decode(CheckinMarkdown.encode(c));

    expect(decoded.recallSkipped, true);
    expect(decoded.yesterdayFindings, isEmpty);
    expect(decoded.socraticQuestion, '');
    expect(decoded.difficulty, isNull);
    expect(decoded.aiRounds, 0);
  });

  test('无行动卡片时解码为 null', () {
    const c = Checkin(date: '2026-09-29');
    final decoded = CheckinMarkdown.decode(CheckinMarkdown.encode(c));
    expect(decoded.actionCard, isNull);
  });

  test('诘问段两个字段互不串味（回归：多标签章节被吞）', () {
    const c = Checkin(
      date: '2026-09-29',
      socraticQuestion: '问题正文',
      userAnswer: '答案正文',
    );
    final decoded = CheckinMarkdown.decode(CheckinMarkdown.encode(c));
    expect(decoded.socraticQuestion, '问题正文');
    expect(decoded.userAnswer, '答案正文');
  });

  test('难度建议文案', () {
    expect(CheckinMarkdown.suggestNext(null), '未评分，明日维持');
    expect(CheckinMarkdown.suggestNext(2), '太简单，明日加难度');
    expect(CheckinMarkdown.suggestNext(5), '维持');
    expect(CheckinMarkdown.suggestNext(8), '太难，明日降维拆解');
  });
}
