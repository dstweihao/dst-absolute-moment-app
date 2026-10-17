import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/enums/app_enums.dart';
import '../../domain/models/checkin.dart';
import '../../domain/models/player_progress.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/icon_tile.dart';
import '../../shared/widgets/progress_bar.dart';
import '../../shared/widgets/progress_icons.dart';
import '../../shared/widgets/section_header.dart';
import '../sop/domain/difficulty_calibrator.dart';

/// 学习统计
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  static const _calibrator = DifficultyCalibrator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkins = ref.watch(allCheckinsProvider);
    final streak = ref.watch(currentStreakProvider);
    final longest = ref.watch(longestStreakProvider);
    final progress = ref.watch(playerProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('学习统计'),
        actions: [
          IconButton(
            tooltip: 'AI 配置',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => context.push(AppRouter.aiSettings),
          ),
        ],
      ),
      body: AsyncView(
        value: checkins,
        onRetry: () => ref.invalidate(allCheckinsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.insights_outlined,
              title: '还没有数据',
              description: '完成第一次打卡后，这里会显示难度趋势、\n'
                  '打卡热力图和五轨轮转分布。',
            );
          }

          final scores = list
              .where((c) => c.difficulty != null)
              .map((c) => c.difficulty!)
              .toList()
              .reversed
              .toList();

          final totalMinutes =
              list.fold<int>(0, (sum, c) => sum + c.durationMinutes);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.lg,
              AppSpacing.pageHorizontal,
              AppSpacing.bottomNavClearance,
            ),
            children: [
              _growthCard(progress.value),
              const SizedBox(height: AppSpacing.cardGap),
              _summaryGrid(
                streak.value ?? 0,
                longest.value ?? 0,
                list.length,
                totalMinutes,
              ),
              const SizedBox(height: AppSpacing.cardGap),
              _difficultyCard(scores),
              const SizedBox(height: AppSpacing.cardGap),
              _rotationCard(list),
              const SizedBox(height: AppSpacing.cardGap),
              _blindSpotCard(list),
              const SizedBox(height: AppSpacing.cardGap),
              _recentCard(list),
            ],
          );
        },
      ),
    );
  }

  /// 成长分区 —— 等级 / 段位 / 经验条 / 已通关数
  Widget _growthCard(PlayerProgress? p) {
    if (p == null) return const SizedBox.shrink();

    final percent = p.xpForNextLevel == 0
        ? 0.0
        : p.xpIntoLevel / p.xpForNextLevel * 100;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '成长'),
          Row(
            children: [
              IconTile(
                size: 48,
                color: AppColors.primary,
                child: Icon(
                  ProgressIcons.forRankTier(p.rankTier),
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lv.${p.level} · ${p.rankTitle}',
                      style: AppTypography.subtitle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LinearProgressBar(percent: percent, height: 8),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${p.xpIntoLevel} / ${p.xpForNextLevel} XP'
                      '  ·  累计 ${p.totalXp}',
                      style: AppTypography.label,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: _statTile('已通关', '${p.clearedNodes}', '关')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _statTile('当前等级', '${p.level}', '级')),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _statTile('累计经验', '${p.totalXp}', 'XP')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryGrid(int streak, int longest, int total, int minutes) {
    final avg = total == 0 ? 0 : (minutes / total).round();
    return Row(
      children: [
        Expanded(child: _statTile('连续', '$streak', '天')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statTile('最长', '$longest', '天')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statTile('累计', '$total', '次')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statTile('平均', '$avg', '分钟')),
      ],
    );
  }

  Widget _statTile(String label, String value, String unit) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTypography.display.copyWith(fontSize: 24)),
          const SizedBox(height: 2),
          Text(unit, style: AppTypography.label),
        ],
      ),
    );
  }

  Widget _difficultyCard(List<int> scores) {
    if (scores.isEmpty) {
      return const SizedBox.shrink();
    }

    final avg = _calibrator.average(scores);
    final hitRate = _calibrator.sweetSpotHitRate(scores);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '难度趋势'),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('平均难度',
                        style: AppTypography.label),
                    const SizedBox(height: AppSpacing.xs),
                    Text(avg.toStringAsFixed(1),
                        style: AppTypography.display.copyWith(fontSize: 28)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('甜蜜点命中率', style: AppTypography.label),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${(hitRate * 100).toStringAsFixed(0)}%',
                        style: AppTypography.display.copyWith(
                          fontSize: 28,
                          color: hitRate >= 0.6
                              ? AppColors.success
                              : AppColors.accent,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _scoreBars(scores),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: AppBorders.badge,
            ),
            child: Row(
              children: [
                Icon(Icons.track_changes, size: 14, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '甜蜜区 3-7 分（猜对 50-70%）。'
                    '落在绿色区间说明难度校准得当。',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBars(List<int> scores) {
    final recent = scores.length > 30
        ? scores.sublist(scores.length - 30)
        : scores;

    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final score in recent)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  height: (score / 10) * 72,
                  decoration: BoxDecoration(
                    color: switch (DifficultyBand.fromScore(score)) {
                      DifficultyBand.tooEasy => AppColors.difficultyTooEasy,
                      DifficultyBand.sweetSpot =>
                        AppColors.difficultySweetSpot,
                      DifficultyBand.tooHard => AppColors.difficultyTooHard,
                    },
                    borderRadius: AppBorders.small,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rotationCard(List<dynamic> checkins) {
    // 按轮转槽位统计各轨道的打卡次数
    final counts = <String, int>{};
    for (final c in checkins) {
      final slot = _slotOf(c.trackId.toString());
      counts[slot] = (counts[slot] ?? 0) + 1;
    }
    final total = checkins.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '五轨轮转分布'),
          Text(
            '目标比例 2:1:1:1:1',
            style: AppTypography.label,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final slot in RotationSlot.values)
            _rotationRow(
              slot.label,
              counts[slot.label] ?? 0,
              total,
              slot.weight,
            ),
        ],
      ),
    );
  }

  Widget _rotationRow(String label, int count, int total, int weight) {
    final percent = total == 0 ? 0.0 : count / total;
    // 目标占比 = 权重 / 权重总和
    final totalWeight = RotationSlot.values
        .fold<int>(0, (sum, s) => sum + s.weight);
    final target = weight / totalWeight;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTypography.caption)),
              Text(
                '$count 次 · ${(percent * 100).toStringAsFixed(0)}%',
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: AppBorders.small,
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor: AppColors.progressEmpty,
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 1,
                child: Text(
                  '目标 ${(target * 100).toStringAsFixed(0)}%',
                  style: AppTypography.label,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recentCard(List<dynamic> checkins) {
    final recent = checkins.take(5).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '最近打卡'),
          for (final c in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(c.date.toString(),
                        style: AppTypography.monoSmall.copyWith(fontSize: 12)),
                  ),
                  Expanded(
                    child: Text(
                      c.nodeTitle.toString().isEmpty
                          ? c.nodeId.toString()
                          : c.nodeTitle.toString(),
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (c.difficulty != null)
                    TagBadge(
                      text: '${c.difficulty}/10',
                      color: switch (DifficultyBand.fromScore(c.difficulty)) {
                        DifficultyBand.tooEasy => AppColors.difficultyTooEasy,
                        DifficultyBand.sweetSpot =>
                          AppColors.difficultySweetSpot,
                        DifficultyBand.tooHard => AppColors.difficultyTooHard,
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _blindSpotCard(List<Checkin> checkins) {
    // 搜集所有已打卡中沉淀的反方证据（我原以为 vs 实际上）
    final items = <_BlindSpotItem>[];
    for (final c in checkins) {
      for (final e in c.counterEvidence) {
        if (e.isComplete) {
          items.add(_BlindSpotItem(
            date: c.date,
            nodeTitle: c.nodeTitle.isEmpty ? c.nodeId : c.nodeTitle,
            assumed: e.assumed,
            actual: e.actual,
          ));
        }
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(title: '认知盲区复盘清单'),
              if (items.isNotEmpty)
                TagBadge(
                  text: '已捕获 ${items.length} 处认知升级',
                  color: AppColors.primary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '“做完项目，你的知识盲区清单比任何内容都更有价值，它是专属于你的系统补强地图。”',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                '暂未记录认知盲区。在阶段③中直面错误假设，写下「我原以为…但实际上…」，系统将在此为你沉淀专属复盘卡。',
                style: AppTypography.caption,
              ),
            )
          else
            for (final item in items.take(6)) ...[
              _blindSpotItemView(item),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }

  Widget _blindSpotItemView(_BlindSpotItem item) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppBorders.card,
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.nodeTitle,
                  style: AppTypography.subtitle.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                item.date,
                style: AppTypography.monoSmall.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('❌ 误区：', style: AppTypography.caption.copyWith(color: AppColors.danger)),
              Expanded(
                child: Text(
                  item.assumed,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡 本质：', style: AppTypography.caption.copyWith(color: AppColors.success)),
              Expanded(
                child: Text(
                  item.actual,
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _slotOf(String trackId) {
    // 目前只有 cpp track，未来多 track 时按 trackId 映射
    return RotationSlot.cppBasics.label;
  }
}

class _BlindSpotItem {
  final String date;
  final String nodeTitle;
  final String assumed;
  final String actual;

  const _BlindSpotItem({
    required this.date,
    required this.nodeTitle,
    required this.assumed,
    required this.actual,
  });
}
