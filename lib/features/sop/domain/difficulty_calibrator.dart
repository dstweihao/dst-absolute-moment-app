import '../../../core/constants/app_constants.dart';
import '../../../domain/enums/app_enums.dart';

/// 难度调整建议
class DifficultyAdjustment {
  /// 如 +1 表示明天加一档
  final int delta;

  final bool inSweetSpot;

  final String rationale;

  /// 连续过难时置位
  final bool needsSideQuest;

  const DifficultyAdjustment({
    required this.delta,
    required this.inSweetSpot,
    required this.rationale,
    this.needsSideQuest = false,
  });

  String get suggestionText {
    if (delta > 0) return '加难度 +$delta';
    if (delta < 0) return '降难度 ${delta.abs()}';
    return '维持';
  }
}

/// 难度校准器 — 刻意练习支柱的校准器
///
/// 方法论依据：**猜对 50-70% 是最佳学习区**（甜蜜点 3-7 分）。
/// 太难则拆解降维，太简单则跳过加速。
///
/// 本类不做任何 IO，纯函数，便于单元测试覆盖各条分支。
class DifficultyCalibrator {
  const DifficultyCalibrator();

  /// 连续过难多少次后触发降维支线
  static const int sideQuestThreshold = 3;

  /// 观察窗口长度
  static const int windowSize = 7;

  /// 甜蜜点范围
  static const int sweetMin = DifficultyConfig.sweetSpotMin;
  static const int sweetMax = DifficultyConfig.sweetSpotMax;

  /// 根据今日评分与近期历史，给出明日调整建议。
  ///
  /// [recentScores] 应为**不含今日**的历史评分，按时间正序（旧→新）。
  DifficultyAdjustment calibrate(int todayScore, List<int> recentScores) {
    final score = todayScore.clamp(1, 10);
    final band = DifficultyBand.fromScore(score);
    final window = recentScores.length > windowSize
        ? recentScores.sublist(recentScores.length - windowSize)
        : recentScores;

    final tooEasyStreak = _trailingStreak(window, DifficultyBand.tooEasy);
    final tooHardStreak = _trailingStreak(window, DifficultyBand.tooHard);

    switch (band) {
      case DifficultyBand.tooEasy:
        // 连续偏易则加大步长，尽快脱离舒适区
        final delta = tooEasyStreak >= 2 ? 2 : 1;
        return DifficultyAdjustment(
          delta: delta,
          inSweetSpot: false,
          rationale: tooEasyStreak >= 2
              ? '连续 ${tooEasyStreak + 1} 次偏易，明天明显加难度'
              : '偏易，明天加一档',
        );

      case DifficultyBand.tooHard:
        // 连续过难 —— 不是加把劲的问题，是底层有洞，该降维了
        if (tooHardStreak >= sideQuestThreshold - 1) {
          return const DifficultyAdjustment(
            delta: -2,
            inSweetSpot: false,
            rationale: '连续多次过难，说明底层概念有洞 —— 建议触发降维支线补给',
            needsSideQuest: true,
          );
        }
        return const DifficultyAdjustment(
          delta: -1,
          inSweetSpot: false,
          rationale: '偏难，明天降一档，先把底层夯实',
        );

      case DifficultyBand.sweetSpot:
        if (score <= sweetMin && tooEasyStreak >= 1) {
          return const DifficultyAdjustment(
            delta: 1,
            inSweetSpot: true,
            rationale: '在甜蜜点边缘偏易，小幅加难度',
          );
        }
        if (score >= sweetMax) {
          return const DifficultyAdjustment(
            delta: -1,
            inSweetSpot: true,
            rationale: '在甜蜜点边缘偏难，小幅降难度',
          );
        }
        return const DifficultyAdjustment(
          delta: 0,
          inSweetSpot: true,
          rationale: '正处于甜蜜点（猜对 50-70%），保持当前梯度',
        );
    }
  }

  int _trailingStreak(List<int> scores, DifficultyBand band) {
    var count = 0;
    for (var i = scores.length - 1; i >= 0; i--) {
      if (DifficultyBand.fromScore(scores[i]) == band) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  double average(List<int> scores) {
    if (scores.isEmpty) return 0;
    final sum = scores.fold<int>(0, (a, b) => a + b);
    return sum / scores.length;
  }

  /// 0.0-1.0，统计页的「校准质量」指标
  double sweetSpotHitRate(List<int> scores) {
    if (scores.isEmpty) return 0;
    final hits = scores.where((s) => DifficultyBand.fromScore(s) ==
        DifficultyBand.sweetSpot).length;
    return hits / scores.length;
  }

  /// 如 `5/10（甜蜜点）`
  String describe(int? score) {
    if (score == null) return '未评分';
    final band = DifficultyBand.fromScore(score);
    return '$score/10（${band.label}）';
  }
}
