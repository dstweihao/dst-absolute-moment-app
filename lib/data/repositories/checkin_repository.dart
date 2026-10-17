import '../../domain/models/action_card.dart';
import '../../domain/models/checkin.dart';
import '../app_paths.dart';
import '../serialization/checkin_markdown.dart';
import '../storage/file_store.dart';

/// 打卡记录仓库
///
/// 每次读写都直接走 WebDAV（不做本地缓存）—— 打卡数据是用户的真实资产，
/// 必须始终以云端为准，避免本地副本与云端不一致。
class CheckinRepository {
  final FileStore client;

  CheckinRepository(this.client);

  /// 列出全部打卡记录，按日期倒序（最新在前）
  Future<List<Checkin>> listAll() async {
    List<StoreEntry> entries;
    try {
      entries = await client.list(AppPaths.checkinsDir);
    } on FileStoreException catch (e) {
      // 目录还不存在 = 还没有任何打卡，不是错误
      if (e.kind == FileStoreErrorKind.notFound) return const [];
      rethrow;
    }

    final files = entries
        .where((e) => !e.isDirectory && e.name.endsWith('.md'))
        .toList()
      ..sort((a, b) => b.name.compareTo(a.name));

    final checkins = <Checkin>[];
    for (final file in files) {
      try {
        final raw = await client.read(file.path);
        final checkin = CheckinMarkdown.decode(raw);
        if (checkin.date.isEmpty) continue;
        checkins.add(checkin);
      } on FileStoreException {
        // 单个文件读取失败不该让整份列表失败
        continue;
      }
    }

    checkins.sort((a, b) => b.date.compareTo(a.date));
    return checkins;
  }

  /// 读取某天的打卡，不存在返回 null
  Future<Checkin?> load(String date) async {
    final raw = await client.readOrNull(AppPaths.checkinFile(date));
    if (raw == null) return null;
    final checkin = CheckinMarkdown.decode(raw);
    return checkin.date.isEmpty ? null : checkin;
  }

  /// 保存打卡。PUT 成功才算成功 —— 失败会抛出，调用方必须如实告知用户。
  Future<void> save(Checkin checkin) async {
    final markdown = CheckinMarkdown.encode(checkin);
    await client.write(AppPaths.checkinFile(checkin.date), markdown);
  }

  Future<void> delete(String date) async {
    await client.delete(AppPaths.checkinFile(date));
  }

  /// 今日是否已打卡
  Future<bool> hasCheckedInToday() async {
    final today = _todayString();
    return (await load(today)) != null;
  }

  /// 最近一次打卡
  Future<Checkin?> latest() async {
    final all = await listAll();
    return all.isEmpty ? null : all.first;
  }

  /// 昨日提取阶段需要的：上一个已完成打卡的 3 条发现
  ///
  /// 传入今日日期，返回**严格早于今日**的最近一次打卡中的发现列表。
  Future<List<String>> previousFindings(String todayDate) async {
    final all = await listAll();
    for (final c in all) {
      if (c.date.compareTo(todayDate) < 0 && c.yesterdayFindings.isNotEmpty) {
        return c.yesterdayFindings;
      }
    }
    return const [];
  }

  /// 是否为用户的首次打卡（决定阶段⓪能否跳过）
  Future<bool> isFirstSession() async {
    final all = await listAll();
    return all.isEmpty;
  }

  /// 已通过的节点 id 集合 —— 用于节点列表的解锁判定
  Future<Set<String>> passedNodeIds() async {
    final all = await listAll();
    return all
        .where((c) => c.completed && c.nodeId.isNotEmpty)
        .map((c) => c.nodeId)
        .toSet();
  }

  /// 收集全部已生成的行动卡片，按来源日期倒序
  Future<List<ActionCard>> allActionCards() async {
    final all = await listAll();
    final cards = <ActionCard>[];
    for (final c in all) {
      final card = c.actionCard;
      if (card != null && card.what.trim().isNotEmpty) {
        cards.add(card);
      }
    }
    cards.sort((a, b) => b.sourceDate.compareTo(a.sourceDate));
    return cards;
  }

  /// 更新某张行动卡片的完成状态
  ///
  /// 做法：读出该日打卡 → 改写卡片 → 整份写回。
  Future<void> toggleActionCard(String date, {required bool done}) async {
    final checkin = await load(date);
    if (checkin == null) return;
    final card = checkin.actionCard;
    if (card == null) return;

    final updated = card.copyWith(
      done: done,
      completedAt: done ? DateTime.now() : null,
    );
    await save(checkin.copyWith(actionCard: updated));
  }

  /// 连续打卡天数（从今天或昨天往前数）
  Future<int> currentStreak() async {
    final dates = (await listAll())
        .map((c) => c.date)
        .where((d) => d.isNotEmpty)
        .toSet();
    if (dates.isEmpty) return 0;

    var cursor = DateTime.now();
    // 今天还没打卡时，从昨天开始数（避免一早就显示断签）
    if (!dates.contains(_format(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (dates.contains(_format(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 历史最长连续打卡天数
  Future<int> longestStreak() async {
    final dates = (await listAll())
        .map((c) => c.date)
        .where((d) => d.isNotEmpty)
        .toList()
      ..sort();
    if (dates.isEmpty) return 0;

    var longest = 1;
    var run = 1;
    for (var i = 1; i < dates.length; i++) {
      final prev = DateTime.tryParse(dates[i - 1]);
      final curr = DateTime.tryParse(dates[i]);
      if (prev == null || curr == null) continue;

      if (curr.difference(prev).inDays == 1) {
        run++;
        longest = run > longest ? run : longest;
      } else {
        run = 1;
      }
    }
    return longest;
  }

  // ------------------------------------------------------------------

  static String _todayString() => _format(DateTime.now());

  static String _format(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
