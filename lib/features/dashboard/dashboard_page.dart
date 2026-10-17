import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/player_progress.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/icon_tile.dart';
import '../../shared/widgets/progress_bar.dart';
import '../../shared/widgets/progress_icons.dart';
import '../../shared/widgets/section_header.dart';

/// 学习看板 —— APP 首页
///
/// 信息优先级（从上到下）：
/// 1. 成长卡（等级 / 段位 / 经验 / 连续 / 已通关）—— 核心成长激励
/// 2. 今日学习（唯一的主行动入口）
/// 3. 总体进度（成就感）
/// 4. 上次行动卡片（闭环提醒）
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayStringProvider);
    final progress = ref.watch(playerProgressProvider);
    final todaysNode = ref.watch(todaysNodeProvider);
    final overall = ref.watch(overallProgressProvider);
    final checkedIn = ref.watch(hasCheckedInTodayProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('绝对时刻'),
        actions: [
          progress.when(
            data: (p) => _LevelBadge(level: p.level),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.lg,
            AppSpacing.pageHorizontal,
            AppSpacing.bottomNavClearance,
          ),
          children: [
            _greeting(today),
            const SizedBox(height: AppSpacing.lg),

            // 成长卡
            AsyncView(
              value: progress,
              builder: (p) => _growthCard(p),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            // 今日核心攻坚
            AsyncView(
              value: todaysNode,
              builder: (node) => _todayCard(
                context,
                node,
                checkedIn.value ?? false,
              ),
            ),
            const SizedBox(height: AppSpacing.cardGap),

            // 总体路线掌握度
            AsyncView(
              value: overall,
              builder: (percent) => _progressCard(context, percent),
            ),
          ],
        ),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(playerProgressProvider)
      ..invalidate(todaysNodeProvider)
      ..invalidate(overallProgressProvider)
      ..invalidate(hasCheckedInTodayProvider)
      ..invalidate(actionCardsProvider);
  }

  Widget _greeting(String today) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? '早上好'
        : hour < 18
            ? '下午好'
            : '晚上好';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        Text(today, style: AppTypography.caption),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 成长卡 —— 等级 / 段位 / 经验 / 连续 / 已通关
  // ------------------------------------------------------------------

  Widget _growthCard(PlayerProgress p) {
    final percent =
        p.xpForNextLevel == 0 ? 0.0 : p.xpIntoLevel / p.xpForNextLevel * 100;
    final isHot = p.streak >= 7;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 段位标记
              IconTile(
                size: 56,
                color: AppColors.primary,
                borderAlpha: 0.22,
                child: Icon(
                  ProgressIcons.forRankTier(p.rankTier),
                  size: 26,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Lv.${p.level}',
                          style: AppTypography.display.copyWith(fontSize: 26),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(p.rankTitle, style: AppTypography.caption),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LinearProgressBar(
                      percent: percent,
                      color: AppColors.primary,
                      height: 8,
                    ),
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
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _growthStat(
                  Icons.local_fire_department_outlined,
                  '${p.streak}',
                  '连续天数',
                  isHot ? AppColors.accent : AppColors.primary,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: AppColors.border,
              ),
              Expanded(
                child: _growthStat(
                  Icons.check_circle_outline,
                  '${p.clearedNodes}',
                  '已通关',
                  AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _growthStat(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: AppTypography.display.copyWith(fontSize: 20, color: color),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.label),
      ],
    );
  }

  // ------------------------------------------------------------------

  Widget _todayCard(BuildContext context, node, bool checkedIn) {
    if (node == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: AppColors.success, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('全部通关', style: AppTypography.subtitle),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('主线节点已全部通过，可以挑战 Bonus 综合实战了。',
                style: AppTypography.caption),
          ],
        ),
      );
    }

    final marker = ProgressIcons.forPhase(node.phase);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('今日攻坚', style: AppTypography.subtitle),
              const Spacer(),
              if (checkedIn)
                TagBadge(text: '今日已完成', color: AppColors.success),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              IconTile(
                size: 48,
                color: AppColors.primary,
                child: Icon(marker, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.title, style: AppTypography.subtitle),
                    const SizedBox(height: 2),
                    Text(
                      '${node.displayNumber} · ${node.progressRangeText}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (node.coreConcepts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '单核心概念：${node.coreConcepts.first}',
                style: AppTypography.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (node.firstQuestion != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '「${node.firstQuestion!.text}」',
              style: AppTypography.caption.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => context.go(AppRouter.learn),
              child: Text(checkedIn ? '继续反诘' : '开始攻坚'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(BuildContext context, double percent) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('总体进度', style: AppTypography.subtitle),
              const Spacer(),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: AppTypography.display.copyWith(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressBar(percent: percent, height: 6),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go(AppRouter.tracks),
              child: const Text('查看路线'),
            ),
          ),
        ],
      ),
    );
  }
}

/// AppBar 上的等级徽章
class _LevelBadge extends StatelessWidget {
  final int level;

  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: AppBorders.badge,
        ),
        child: Text(
          'Lv.$level',
          style: AppTypography.label.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
