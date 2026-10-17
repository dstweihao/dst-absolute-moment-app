import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/node.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/back_leading.dart';
import '../../shared/widgets/icon_tile.dart';
import '../../shared/widgets/progress_icons.dart';
import '../../shared/widgets/section_header.dart';

/// 节点详情 —— 进入 SOP 前的最后确认页
///
/// 一个关卡只讲一件事，所以这一页也只有四块：
/// 本关内容（1 个概念）→ 这一关的问题（1 个诘问）→ 怎么算过关（1 条验收）
/// → 开始。多余的分组、关键词、判定维度都已砍掉。
class NodeDetailPage extends ConsumerWidget {
  final String trackId;
  final String nodeId;

  const NodeDetailPage({
    super.key,
    required this.trackId,
    required this.nodeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider(trackId));
    final passed = ref.watch(passedNodeIdsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: PageBackButton(fallback: AppRouter.nodesOf(trackId)),
        title: const Text('节点详情'),
      ),
      body: AsyncView(
        value: nodes,
        onRetry: () => ref.invalidate(nodesProvider(trackId)),
        builder: (list) {
          Node? node;
          for (final n in list) {
            if (n.id == nodeId) {
              node = n;
              break;
            }
          }

          if (node == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: '找不到该节点',
            );
          }

          final isPassed = (passed.value ?? const {}).contains(node.id);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.lg,
              AppSpacing.pageHorizontal,
              AppSpacing.xxl,
            ),
            children: [
              _title(node, isPassed),
              const SizedBox(height: AppSpacing.lg),

              if (node.description.isNotEmpty) ...[
                AppCard(
                  child: Text(node.description, style: AppTypography.body),
                ),
                const SizedBox(height: AppSpacing.cardGap),
              ],

              if (node.coreConcepts.isNotEmpty) ...[
                const SectionHeader(title: '本关内容'),
                AppCard(child: _bulletList(node.coreConcepts)),
                const SizedBox(height: AppSpacing.cardGap),
              ],

              if (node.questions.isNotEmpty) ...[
                const SectionHeader(title: '这一关的问题'),
                AppCard(child: _question(node.questions.first)),
                const SizedBox(height: AppSpacing.cardGap),
              ],

              if (node.acceptanceCriteria.isNotEmpty ||
                  !node.interception.isEmpty) ...[
                const SectionHeader(title: '怎么算过关'),
                AppCard(child: _passCriteria(node)),
              ],

              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final nid = node?.id;
                    if (nid != null) {
                      ref.read(activeLearningNodeIdProvider.notifier).select(nid);
                    }
                    context.go(AppRouter.learn);
                  },
                  child: Text(isPassed ? '继续反诘' : '开始攻坚'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _title(Node node, bool isPassed) {
    final accent = isPassed ? AppColors.success : AppColors.primary;
    final marker = isPassed
        ? ProgressIcons.passed
        : node.isSupplementary
            ? ProgressIcons.elective
            : ProgressIcons.forPhase(node.phase);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 与路线页的时间线标记同一套视觉：圆角方块，不是圆头像
        IconTile(
          size: 52,
          color: accent,
          borderAlpha: 0.30,
          child: Icon(marker, size: 24, color: accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    node.isBonus
                        ? 'Bonus'
                        : node.isSupplementary
                            ? '补充关'
                            : '关卡 ${node.displayNumber}',
                    style: AppTypography.monoSmall.copyWith(fontSize: 12),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (isPassed)
                    TagBadge(text: '已通过', color: AppColors.success)
                  else if (node.isSupplementary)
                    const TagBadge(text: '补充')
                  else
                    TagBadge(text: '+30 XP', color: AppColors.success),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(node.title, style: AppTypography.title),
              const SizedBox(height: AppSpacing.xs),
              Text(
                node.isSupplementary
                    ? node.phaseName
                    : '${node.progressRangeText}  ·  ${node.phaseName}',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: AppTypography.body),
                Expanded(child: Text(item, style: AppTypography.body)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _question(dynamic q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (q.level != null) ...[
          TagBadge(text: '难度 ${q.level}'),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(q.text.toString(), style: AppTypography.body),
      ],
    );
  }

  Widget _passCriteria(Node node) {
    final c = node.interception;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in node.acceptanceCriteria)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_box_outline_blank,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(item, style: AppTypography.body)),
              ],
            ),
          ),
        if (c.minimumPassLine.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          InfoRow(label: '最低通过线', value: c.minimumPassLine),
        ],
        if (c.onFailure.isNotEmpty)
          InfoRow(
            label: '未通过',
            value: c.onFailure,
            valueColor: AppColors.accent,
          ),
      ],
    );
  }
}
