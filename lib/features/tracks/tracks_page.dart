import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/progress_bar.dart';
import '../../shared/widgets/section_header.dart';

/// 路线列表 —— 把每条 route 当作一张「世界地图」
class TracksPage extends ConsumerWidget {
  const TracksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(allTracksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('学习路线'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 清掉仓库缓存再让 provider 重取，才能真正拉到云端最新数据
              ref.read(trackRepositoryProvider).invalidate();
              ref.invalidate(allTracksProvider);
            },
          ),
        ],
      ),
      body: AsyncView(
        value: tracks,
        onRetry: () => ref.invalidate(allTracksProvider),
        loading: const Padding(
          padding: EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Column(
            children: [
              _Skeleton(height: 140),
              SizedBox(height: AppSpacing.cardGap),
              _Skeleton(height: 140),
            ],
          ),
        ),
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.map_outlined,
              title: '没有可用的学习路线',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.lg,
              AppSpacing.pageHorizontal,
              AppSpacing.bottomNavClearance,
            ),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.cardGap),
            itemBuilder: (context, index) =>
                _TrackCard(track: list[index]),
          );
        },
      ),
    );
  }
}

class _TrackCard extends ConsumerWidget {
  final dynamic track;

  const _TrackCard({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider(track.id));
    final passed = ref.watch(passedNodeIdsProvider);
    final repo = ref.watch(trackRepositoryProvider);

    final all = nodes.value ?? const [];
    final mainline = all.where((n) => !n.isBonus && !n.isSupplementary);
    final total = mainline.length;
    final passedIds = passed.value ?? const <String>{};
    final passedCount =
        mainline.where((n) => passedIds.contains(n.id)).length;

    final percent = repo.overallProgress(all, passedIds);
    final cleared = total > 0 && passedCount >= total;

    return AppCard(
      onTap: () => context.go(AppRouter.nodesOf(track.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(track.title, style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(track.description, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: AppTypography.display.copyWith(fontSize: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('已通过 $passedCount / $total 关',
                  style: AppTypography.caption),
              const Spacer(),
              if (cleared) TagBadge(text: '已全部通过', color: AppColors.success),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressBar(percent: percent, height: 6),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;

  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppBorders.card,
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}
