/// 七阶段 SOP、轮转比例、难度评级等全局常量
library;

class SopStages {
  SopStages._();

  static const int stageCount = 7;

  /// 每阶段默认分钟数
  static const Map<int, int> defaultMinutes = {
    0: 2,
    1: 5,
    2: 5,
    3: 20,
    4: 18,
    5: 8,
    6: 2,
  };

  /// 全程 60 分钟
  static const int totalMinutes = 60;

  static const Map<int, String> labels = {
    0: '⓪ 昨日提取',
    1: '① 诘问',
    2: '② 拆解',
    3: '③ 验证',
    4: '④ 机制阐释',
    5: '⑤ 实践卡片',
    6: '⑥ 难度自评',
  };

  static const Map<int, String> descriptions = {
    0: '凭记忆写出上轮的3个关键发现（不翻笔记）',
    1: '凭第一反应回答当日问题，禁止查任何资料',
    2: '拆解答案，找出最脆弱的假设（今日靶心）',
    3: '找到至少1条反方证据（"我原以为X，实际物理机制是Y"）',
    4: '用通俗准确的工程语言阐释底层机制与避坑点',
    5: '输出一张具体可验证的 C++ 实践行动卡片',
    6: '给今日难度打分（1-10），校准明日梯度',
  };
}

class RotationConfig {
  RotationConfig._();

  static const List<String> rotationQueue = [
    'C++基础语法与内存',
    'C++现代特性与泛型',
    '系统并发与内存序',
    '性能优化与底层机制',
    '工程工具链与复盘',
  ];

  /// 均衡分配
  static const Map<String, int> defaultWeights = {
    'C++基础语法与内存': 2,
    'C++现代特性与泛型': 2,
    '系统并发与内存序': 1,
    '性能优化与底层机制': 1,
    '工程工具链与复盘': 1,
  };

  /// 每完成 N 次闭环触发复盘
  static const int roundsPerReview = 5;
}

class DifficultyConfig {
  DifficultyConfig._();

  /// 甜蜜点范围（猜对 50-70%）
  static const int sweetSpotMin = 3;
  static const int sweetSpotMax = 7;
  static const int minRating = 1;
  static const int maxRating = 10;
}

class DatabaseConfig {
  DatabaseConfig._();

  static const String dbName = 'absolute_moment.db';
  static const int dbVersion = 1;
}