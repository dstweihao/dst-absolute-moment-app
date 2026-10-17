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
import '../../shared/widgets/progress_icons.dart';
import '../../shared/widgets/progress_bar.dart';
import '../../shared/widgets/section_header.dart';

/// 节点路径页 —— 竖向关卡时间线
///
/// 左侧一条进度脊柱串起整条路线，每关是一张克制的关卡卡片，
/// 一关只讲一件事。个性化资源扫出来的节点作为「补充关」列在主线之后，
/// 不占主线进度，也不参与「今日攻坚」的自动选关。
class NodesPage extends ConsumerWidget {
  final String trackId;

  const NodesPage({super.key, required this.trackId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider(trackId));
    final passed = ref.watch(passedNodeIdsProvider);
    final repo = ref.watch(trackRepositoryProvider);
    final tracks = ref.watch(allTracksProvider);

    var trackTitle = '学习路线';
    for (final t in tracks.value ?? const []) {
      if (t.id == trackId) {
        trackTitle = t.title;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const PageBackButton(fallback: AppRouter.tracks),
        title: Text(trackTitle),
      ),
      body: AsyncView(
        value: nodes,
        onRetry: () => ref.invalidate(nodesProvider(trackId)),
        builder: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_off_outlined,
              title: '没有找到节点数据',
            );
          }

          final passedIds = passed.value ?? const <String>{};
          final percent = repo.overallProgress(list, passedIds);
          final todays = repo.nextNode(list, passedIds);
          final mainline = list.where((n) => !n.isBonus && !n.isSupplementary);
          final total = mainline.length;
          final slain = mainline.where((n) => passedIds.contains(n.id)).length;
          final extras =
              list.where((n) => n.isSupplementary).toList(growable: false);

          // 按阶段分组，保持节点原有顺序（补充关不进阶段分组）
          final grouped = <int, List<Node>>{};
          for (final node in list) {
            if (node.isSupplementary) continue;
            grouped.putIfAbsent(node.phase, () => []).add(node);
          }
          final phases = grouped.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.lg,
              AppSpacing.pageHorizontal,
              AppSpacing.bottomNavClearance,
            ),
            children: [
              _header(percent, slain, total, supplementCount: extras.length),
              const SizedBox(height: AppSpacing.sm),

              for (final phase in phases) ...[
                SectionHeader(
                  title: '阶段${_phaseLabel(phase)} · '
                      '${grouped[phase]!.first.phaseName}',
                  trailing: '${grouped[phase]!.length} 关',
                ),
                _timeline(
                  context,
                  list: grouped[phase]!,
                  passedIds: passedIds,
                  todaysId: todays?.id,
                  isLocked: (n) => repo.isLocked(n, passedIds),
                  trackId: trackId,
                ),
              ],

              if (extras.isNotEmpty) ...[
                SectionHeader(
                  title: '个性化补充',
                  trailing: '${extras.length} 关',
                ),
                _timeline(
                  context,
                  list: extras,
                  passedIds: passedIds,
                  todaysId: null,
                  isLocked: (_) => false,
                  trackId: trackId,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------

  Widget _header(
    double percent,
    int slain,
    int total, {
    required int supplementCount,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('关卡进度', style: AppTypography.subtitle),
              const Spacer(),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: AppTypography.display.copyWith(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressBar(percent: percent, height: 6),
          const SizedBox(height: AppSpacing.sm),
          Text('已通过 $slain / $total 关', style: AppTypography.caption),
          if (supplementCount > 0) ...[
            const SizedBox(height: 2),
            Text(
              '另有 $supplementCount 个补充关（不计入进度）',
              style: AppTypography.label,
            ),
          ],
        ],
      ),
    );
  }

  /// 一阶段的竖向关卡时间线
  Widget _timeline(
    BuildContext context, {
    required List<Node> list,
    required Set<String> passedIds,
    required String? todaysId,
    required bool Function(Node) isLocked,
    required String trackId,
  }) {
    // 阶段内最后一个非 Bonus 节点 = 阶段收官
    final closingId = list.lastWhere(
      (n) => !n.isBonus,
      orElse: () => list.last,
    ).id;

    return Column(
      children: [
        for (var i = 0; i < list.length; i++)
          _TimelineRow(
            node: list[i],
            isFirst: i == 0,
            isLast: i == list.length - 1,
            isClosing: list[i].id == closingId && !list[i].isBonus,
            isPassed: passedIds.contains(list[i].id),
            isToday: todaysId == list[i].id,
            locked: isLocked(list[i]),
            onTap: () => _onTap(
              context,
              list[i],
              isLocked(list[i]),
              trackId,
            ),
          ),
      ],
    );
  }

  static String _phaseLabel(int phase) {
    const labels = ['', '一', '二', '三', '四', '五'];
    return phase >= 1 && phase < labels.length ? labels[phase] : '$phase';
  }

  void _onTap(
    BuildContext context,
    Node node,
    bool locked,
    String trackId,
  ) {
    if (locked) {
      // 进度锁定铁律 —— 明确告知为什么进不去
      final missing = node.prerequisites.join('、');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('这一关还锁着\n需先通过：$missing')),
      );
      return;
    }
    context.go(AppRouter.nodeDetail(trackId, node.id));
  }
}

/// 时间线的一行：左侧脊柱 + 关卡标记，右侧关卡卡片
class _TimelineRow extends StatelessWidget {
  final Node node;
  final bool isFirst;
  final bool isLast;
  final bool isClosing;
  final bool isPassed;
  final bool isToday;
  final bool locked;
  final VoidCallback onTap;

  const _TimelineRow({
    required this.node,
    required this.isFirst,
    required this.isLast,
    required this.isClosing,
    required this.isPassed,
    required this.isToday,
    required this.locked,
    required this.onTap,
  });

  /// 标记方块边长的一半 —— 脊柱要在标记中心收尾
  static const double _markerSize = 40;
  static const double _gutterWidth = 48;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _gutter(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              // 卡片之间的空隙留在脊柱内侧，线才是连续的
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _card(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gutter() {
    final accent = _accentColor;
    // 首行的线从标记中心起，末行的线到标记中心止
    final topLine = isFirst ? Colors.transparent : AppColors.border;
    final bottomLine = isLast ? Colors.transparent : AppColors.border;

    return SizedBox(
      width: _gutterWidth,
      child: Column(
        children: [
          SizedBox(
            height: _markerSize / 2,
            child: Center(child: Container(width: 2, color: topLine)),
          ),
          _marker(accent),
          Expanded(
            child: Center(child: Container(width: 2, color: bottomLine)),
          ),
        ],
      ),
    );
  }

  Widget _marker(Color accent) {
    final bg = locked
        ? AppColors.surfaceVariant
        : isPassed
            ? AppColors.success.withValues(alpha: 0.10)
            : isToday
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.surface;

    return Container(
      width: _markerSize,
      height: _markerSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppBorders.tile,
        border: Border.all(color: accent, width: isToday ? 2 : 1.5),
      ),
      child: Icon(
        _markerIcon,
        size: 19,
        color: locked
            ? AppColors.textDisabled
            : isPassed
                ? AppColors.success
                : AppColors.textSecondary,
      ),
    );
  }

  Widget _card() {
    final concept = node.coreConcepts.isNotEmpty ? node.coreConcepts.first : null;
    final question = node.firstQuestion?.text;

    return AppCard(
      accentColor: isToday ? AppColors.primary : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _numberLabel,
                style: AppTypography.monoSmall.copyWith(
                  fontSize: 12,
                  color: locked
                      ? AppColors.textDisabled
                      : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              _badge(),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            node.title,
            style: AppTypography.subtitle.copyWith(
              color: locked ? AppColors.textDisabled : AppColors.textPrimary,
            ),
          ),
          if (concept != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (locked ? AppColors.textDisabled : AppColors.primary)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                concept,
                style: AppTypography.label.copyWith(
                  fontSize: 11,
                  color: locked ? AppColors.textDisabled : AppColors.primary,
                ),
              ),
            ),
          ],
          if (question != null && !locked) ...[
            const SizedBox(height: 6),
            Text(
              question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (isToday) ...[
            const SizedBox(height: AppSpacing.sm),
            _challengePill(),
          ],
        ],
      ),
    );
  }

  String get _numberLabel {
    if (node.isBonus) return 'Bonus 综合实战';
    return '关卡 ${node.displayNumber} · ${node.progressRangeText}';
  }

  Widget _badge() {
    if (locked) {
      return const TagBadge(text: '未解锁');
    }
    if (isPassed) {
      return TagBadge(text: '已通过', color: AppColors.success);
    }
    if (isToday) {
      return const TagBadge(text: '今日攻坚');
    }
    if (isClosing) {
      return const TagBadge(text: '阶段收官');
    }
    return const SizedBox.shrink();
  }

  Widget _challengePill() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppBorders.badge,
      ),
      child: Text(
        '开始本关',
        style: AppTypography.label.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  IconData get _markerIcon {
    if (locked) return ProgressIcons.locked;
    if (isPassed) return ProgressIcons.passed;
    if (node.isSupplementary) return ProgressIcons.elective;
    if (node.isBonus) return ProgressIcons.elective;
    if (isClosing) return ProgressIcons.closing;
    return ProgressIcons.forPhase(node.phase);
  }

  Color get _accentColor {
    if (locked) return AppColors.border;
    if (isPassed) return AppColors.success.withValues(alpha: 0.45);
    if (isToday) return AppColors.primary;
    return AppColors.border;
  }
}
