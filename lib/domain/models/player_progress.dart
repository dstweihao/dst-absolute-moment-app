import 'checkin.dart';

/// 成长档案 —— 等级与经验的数值模型
///
/// **纯派生，不新增存储**：`from` 工厂直接由 [Checkin] 列表算出，
/// 与「连续打卡 / 进度」同源，天然一致。
/// 每完成一次闭环打卡累计经验（XP），升级并晋升段位。
class PlayerProgress {
  final int totalXp;

  /// 1 起
  final int level;

  final int xpIntoLevel;

  /// 进度条分母，= `50 * level`
  final int xpForNextLevel;

  final String rankTitle;

  /// 1 最低，6 最高。表现层据此选图标，领域层不碰 UI。
  final int rankTier;

  final int clearedNodes;

  final int streak;

  const PlayerProgress({
    required this.totalXp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.rankTitle,
    required this.rankTier,
    required this.clearedNodes,
    required this.streak,
  });

  factory PlayerProgress.from(
    List<Checkin> checkins, {
    required int clearedNodes,
    required int streak,
  }) {
    var xp = 0;
    for (final c in checkins) {
      if (!c.completed) continue;
      xp += xpForCheckin(c);
    }

    final lvl = levelForXp(xp);
    final (rankTitle, rankTier) = rankForLevel(lvl);

    return PlayerProgress(
      totalXp: xp,
      level: lvl,
      xpIntoLevel: xpIntoNextLevel(xp),
      xpForNextLevel: xpNeededForNext(xp),
      rankTitle: rankTitle,
      rankTier: rankTier,
      clearedNodes: clearedNodes,
      streak: streak,
    );
  }

  /// 通关基础 +30；难度落在甜蜜区 3-7 额外 +10；AI 协助 +5；
  /// AI 拷问轮次每轮 +1（封顶 5）。
  static int xpForCheckin(Checkin c) {
    var xp = 30;
    final d = c.difficulty;
    if (d != null && d >= 3 && d <= 7) xp += 10;
    if (c.aiAssisted) xp += 5;
    xp += c.aiRounds.clamp(0, 5);
    return xp;
  }

  /// 升到 L 级需要的累计 XP（L<=1 为 0）。
  ///
  /// 升到 L+1 级需 `50 * L` XP，故累计为 `25 * L * (L-1)`。
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return 25 * level * (level - 1);
  }

  static int levelForXp(int xp) {
    var level = 1;
    while (xp >= xpForLevel(level + 1)) {
      level++;
    }
    return level;
  }

  static int xpIntoNextLevel(int xp) => xp - xpForLevel(levelForXp(xp));

  /// = `50 * level`
  static int xpNeededForNext(int xp) => 50 * levelForXp(xp);

  /// 段位阶梯 —— 返回 (段位名, 层级 1-6)。
  ///
  /// 只出文字与层级数字；图标是表现层的事，见 `ProgressIcons.forRankTier`。
  static (String, int) rankForLevel(int level) {
    if (level >= 15) return ('传奇', 6);
    if (level >= 10) return ('钻石', 5);
    if (level >= 7) return ('铂金', 4);
    if (level >= 5) return ('黄金', 3);
    if (level >= 3) return ('白银', 2);
    return ('青铜', 1);
  }
}
