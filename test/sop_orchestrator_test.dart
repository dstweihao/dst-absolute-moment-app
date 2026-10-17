import 'package:absolute_moment_app/domain/enums/app_enums.dart';
import 'package:absolute_moment_app/domain/models/action_card.dart';
import 'package:absolute_moment_app/domain/models/checkin.dart';
import 'package:absolute_moment_app/features/sop/domain/sop_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

const orchestrator = SopOrchestrator();

Checkin draft({
  bool recallSkipped = false,
  List<String> findings = const [],
  String answer = '',
  String assumption = '',
  List<CounterEvidence> evidence = const [],
  String translation = '',
  ActionCard? card,
  int? difficulty,
}) =>
    Checkin(
      date: '2026-09-29',
      recallSkipped: recallSkipped,
      yesterdayFindings: findings,
      userAnswer: answer,
      weakestAssumption: assumption,
      counterEvidence: evidence,
      businessTranslation: translation,
      actionCard: card,
      difficulty: difficulty,
    );

void main() {
  group('阶段⓪ 昨日提取', () {
    test('首次会话允许跳过', () {
      final v = orchestrator.validate(
        SopStageType.recall,
        draft(recallSkipped: true),
        isFirstSession: true,
      );
      expect(v.canAdvance, true);
    });

    test('非首次会话不能跳过', () {
      final v = orchestrator.validate(
        SopStageType.recall,
        draft(recallSkipped: true),
        isFirstSession: false,
      );
      expect(v.canAdvance, false);
    });

    test('非首次需写满 3 条发现', () {
      final few = orchestrator.validate(
        SopStageType.recall,
        draft(findings: const ['a', 'b']),
        isFirstSession: false,
      );
      expect(few.canAdvance, false);

      final full = orchestrator.validate(
        SopStageType.recall,
        draft(findings: const ['a', 'b', 'c']),
        isFirstSession: false,
      );
      expect(full.canAdvance, true);
    });

    test('发现为空串仍被拦截', () {
      final v = orchestrator.validate(
        SopStageType.recall,
        draft(findings: const ['a', '  ', 'c']),
        isFirstSession: false,
      );
      expect(v.canAdvance, false);
    });
  });

  group('各阶段空缺拦截', () {
    test('① 诘问需第一反应答案', () {
      expect(orchestrator.validate(SopStageType.questioning, draft(), isFirstSession: false).canAdvance, false);
      expect(orchestrator.validate(SopStageType.questioning, draft(answer: 'x'), isFirstSession: false).canAdvance, true);
    });

    test('② 拆解需最脆弱假设', () {
      expect(orchestrator.validate(SopStageType.breakdown, draft(), isFirstSession: false).canAdvance, false);
      expect(orchestrator.validate(SopStageType.breakdown, draft(assumption: 'x'), isFirstSession: false).canAdvance, true);
    });

    test('④ 转化需商业翻译', () {
      expect(orchestrator.validate(SopStageType.translation, draft(), isFirstSession: false).canAdvance, false);
      expect(orchestrator.validate(SopStageType.translation, draft(translation: 'x'), isFirstSession: false).canAdvance, true);
    });

    test('⑥ 自评需 1-10 难度分', () {
      expect(orchestrator.validate(SopStageType.selfRating, draft(), isFirstSession: false).canAdvance, false);
      expect(orchestrator.validate(SopStageType.selfRating, draft(difficulty: 0), isFirstSession: false).canAdvance, false);
      expect(orchestrator.validate(SopStageType.selfRating, draft(difficulty: 11), isFirstSession: false).canAdvance, false);
      expect(orchestrator.validate(SopStageType.selfRating, draft(difficulty: 7), isFirstSession: false).canAdvance, true);
    });
  });

  group('阶段③ 验证（最硬关卡）', () {
    test('无证据锁死', () {
      final v = orchestrator.validate(SopStageType.verification, draft(), isFirstSession: false);
      expect(v.canAdvance, false);
      expect(v.blockers, isNotEmpty);
    });

    test('只有「我原以为」不算完整证据', () {
      final d = draft(evidence: const [CounterEvidence(assumed: '只有一半')]);
      expect(orchestrator.validate(SopStageType.verification, d, isFirstSession: false).canAdvance, false);
    });

    test('一条完整证据放行', () {
      final d = draft(evidence: const [CounterEvidence(assumed: 'a', actual: 'b')]);
      expect(orchestrator.validate(SopStageType.verification, d, isFirstSession: false).canAdvance, true);
    });
  });

  group('阶段⑤ 行动卡片', () {
    test('缺卡锁死', () {
      expect(orchestrator.validate(SopStageType.actionCard, draft(), isFirstSession: false).canAdvance, false);
    });

    test('四要素齐全才放行', () {
      final full = draft(
        card: ActionCard(
          id: 'x',
          sourceDate: '2026-09-29',
          what: 'a',
          whenText: 'b',
          criteria: 'c',
          businessValue: 'd',
        ),
      );
      expect(orchestrator.validate(SopStageType.actionCard, full, isFirstSession: false).canAdvance, true);

      final partial = draft(
        card: ActionCard(id: 'x', sourceDate: '2026-09-29', what: 'a'),
      );
      expect(orchestrator.validate(SopStageType.actionCard, partial, isFirstSession: false).canAdvance, false);
    });
  });

  group('跳阶 / 前进', () {
    test('只允许紧邻前进，禁止跳阶与回退', () {
      expect(orchestrator.canJumpTo(SopStageType.breakdown, SopStageType.questioning), true);
      expect(orchestrator.canJumpTo(SopStageType.verification, SopStageType.questioning), false);
      expect(orchestrator.canJumpTo(SopStageType.questioning, SopStageType.questioning), false);
      expect(orchestrator.canJumpTo(SopStageType.recall, SopStageType.questioning), false);
    });

    test('nextStage 边界', () {
      expect(orchestrator.nextStage(SopStageType.questioning), SopStageType.breakdown);
      expect(orchestrator.nextStage(SopStageType.selfRating), isNull);
    });

    test('canGoBack', () {
      expect(orchestrator.canGoBack(SopStageType.recall), false);
      expect(orchestrator.canGoBack(SopStageType.questioning), true);
    });
  });
}
