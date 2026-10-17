import '../../../domain/enums/app_enums.dart';
import '../../../domain/models/checkin.dart';

/// 单个阶段的校验结果
class StageValidation {
  /// 是否允许推进到下一阶段
  final bool canAdvance;

  /// 阻止推进的原因（人类可读），canAdvance 为 false 时非空
  final List<String> blockers;

  const StageValidation({required this.canAdvance, this.blockers = const []});

  static const StageValidation pass = StageValidation(canAdvance: true);

  /// 供 UI 直接展示的提示文本
  String get message => blockers.isEmpty ? '' : blockers.first;
}

/// 苏格拉底七阶段 SOP 推进校验器
///
/// 这是 APP 的核心业务规则，直接对应 SKILL.md 的「进度锁定铁律」：
/// **没有通过当前阶段的验收标准，绝不放行。**
///
/// 三条硬规则：
/// 1. 阶段 0-6 必须顺序推进，**绝对禁止跳阶**
/// 2. 阶段③ 验证**必须至少 1 条完整反方证据**，否则锁死
/// 3. 阶段⓪ 昨日提取**仅首次会话可跳过**，之后必须填满 3 条
class SopOrchestrator {
  const SopOrchestrator();

  /// 首次会话需要填写的关键发现条数
  static const int requiredFindings = 3;

  /// 阶段③ 需要的最少反方证据条数
  static const int requiredEvidence = 1;

  /// 校验某个阶段是否已达推进条件。
  ///
  /// [stage] 当前所处阶段；[draft] 正在填写的打卡草稿；
  /// [isFirstSession] 是否为用户的第一次打卡（决定阶段⓪能否跳过）。
  StageValidation validate(
    SopStageType stage,
    Checkin draft, {
    required bool isFirstSession,
  }) {
    final blockers = <String>[];

    switch (stage) {
      case SopStageType.recall:
        // 首次会话允许跳过；非首次必须凭记忆写出 3 条
        if (isFirstSession && draft.recallSkipped) break;
        if (draft.yesterdayFindings.length < requiredFindings) {
          blockers.add('需要写出 $requiredFindings 条关键发现'
              '（已填 ${draft.yesterdayFindings.length} 条）');
        }
        for (var i = 0; i < draft.yesterdayFindings.length; i++) {
          if (draft.yesterdayFindings[i].trim().isEmpty) {
            blockers.add('第 ${i + 1} 条发现不能为空');
          }
        }
        break;

      case SopStageType.questioning:
        if (draft.userAnswer.trim().isEmpty) {
          blockers.add('必须先写下你的第一反应答案，禁止查资料');
        }
        break;

      case SopStageType.breakdown:
        if (draft.weakestAssumption.trim().isEmpty) {
          blockers.add('必须揪出你答案里最脆弱的假设（今日靶心）');
        }
        break;

      case SopStageType.verification:
        // ★ 全 APP 最硬的一道关卡
        if (draft.validEvidenceCount < requiredEvidence) {
          blockers.add(
            '必须找到至少 $requiredEvidence 条完整的反方证据'
            '（「我原以为」和「但实际上」都要填）',
          );
        }
        break;

      case SopStageType.translation:
        if (draft.businessTranslation.trim().isEmpty) {
          blockers.add('必须写下机制阐释 —— 用通俗清晰的工程语言讲清底层机制');
        }
        break;

      case SopStageType.actionCard:
        final card = draft.actionCard;
        if (card == null) {
          blockers.add('必须生成行动卡片');
        } else {
          final missing = card.missingFields;
          if (missing.isNotEmpty) {
            blockers.add('行动卡片还缺：${missing.join('、')}');
          }
        }
        break;

      case SopStageType.selfRating:
        final d = draft.difficulty;
        if (d == null) {
          blockers.add('必须为今日难度打分（1-10）');
        } else if (d < 1 || d > 10) {
          blockers.add('难度分必须在 1-10 之间');
        }
        break;
    }

    return StageValidation(
      canAdvance: blockers.isEmpty,
      blockers: blockers,
    );
  }

  /// 判断能否从 [current] 跳到 [target]。
  ///
  /// 铁律：只允许前进到**紧邻的下一阶段**，禁止跳阶、禁止回退
  /// （回退由单独的「要求返工」流程处理，不走此方法）。
  bool canJumpTo(SopStageType target, SopStageType current) {
    return target.index == current.index + 1;
  }

  /// 给定当前阶段，返回下一阶段；已是最后一阶段则返回 null
  SopStageType? nextStage(SopStageType current) {
    final next = current.index + 1;
    if (next >= SopStageType.values.length) return null;
    return SopStageType.fromIndex(next);
  }

  /// 是否可以回看上一阶段（只读，不允许修改已提交内容）
  bool canGoBack(SopStageType current) => current.index > 0;

  /// 全部阶段是否都已走完
  bool isSessionComplete(Checkin draft, {required bool isFirstSession}) {
    for (final stage in SopStageType.values) {
      if (!validate(stage, draft, isFirstSession: isFirstSession).canAdvance) {
        return false;
      }
    }
    return true;
  }

  /// 返回第一个未通过的阶段，用于「继续上次进度」功能
  SopStageType? firstIncompleteStage(
    Checkin draft, {
    required bool isFirstSession,
  }) {
    for (final stage in SopStageType.values) {
      if (!validate(stage, draft, isFirstSession: isFirstSession).canAdvance) {
        return stage;
      }
    }
    return null;
  }

  /// 已完成阶段的进度比例 0.0-1.0，用于顶部进度条
  double completionRatio(Checkin draft, SopStageType current) {
    final total = SopStageType.values.length;
    if (total == 0) return 0;
    return (current.index / total).clamp(0.0, 1.0);
  }
}
