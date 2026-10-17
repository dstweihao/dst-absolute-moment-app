import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/checkin.dart';
import '../../domain/models/source_material.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/back_leading.dart';
import '../../shared/widgets/icon_tile.dart';

/// SOP 准备页 —— 阶段 0：输入源建档
///
/// 进入七阶段之前先确认今天的输入源。这一步不能省 —— 同样的关卡，
/// 手边有教材和纯白板，拆塔官该问的问题完全不同。
///
/// 输入源**来自个性化资源文件夹**（设置里选定），不是一个靠用户手打的
/// 自由文本框：文件夹里那些 `.md` / `.txt` 笔记就是他的真实业务背景，
/// 勾选后正文随提示词一起发给 AI。文件夹是空的也照样能开始 —— 纯白板
/// 是一种正当选择，不是失败状态。
class SopSetupPage extends ConsumerStatefulWidget {
  const SopSetupPage({super.key});

  @override
  ConsumerState<SopSetupPage> createState() => _SopSetupPageState();
}

class _SopSetupPageState extends ConsumerState<SopSetupPage> {
  /// 手写补充的背景 —— 文件夹里没有、但今天需要交代给 AI 的上下文
  final _backgroundController = TextEditingController();

  /// 本次勾选的物料路径。
  ///
  /// `null` = 用户还没动过 → 视为**全选**。文件夹是用户自己在设置里挑的，
  /// 里面就是他今天手边的材料，没有理由让他在会话开始前再勾一遍。
  /// 一旦他手动取消勾选，才落成一份显式集合。
  Set<String>? _selected;

  /// 生效的勾选集合：没动过就是全选
  Set<String> _selectionOf(List<SourceMaterial> materials) =>
      _selected ?? materials.map((m) => m.path).toSet();

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayStringProvider);
    final todaysNode = ref.watch(todaysNodeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('准备开始'),
        leading: const PageBackButton(fallback: AppRouter.dashboard),
      ),
      body: AsyncView(
        value: todaysNode,
        builder: (node) {
          if (node == null) {
            return const EmptyState(
              icon: Icons.emoji_events,
              title: '全部通关了',
              description: '主线节点已全部通过。',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.lg,
              AppSpacing.pageHorizontal,
              AppSpacing.xxl,
            ),
            children: [
              _nodePreview(node),
              const SizedBox(height: AppSpacing.cardGap),
              _intakeCard(),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _start(node, today),
                  child: const Text('开始 60 分钟闭环'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _nodePreview(dynamic node) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('今日攻坚', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              IconTile(
                size: 44,
                color: AppColors.primary,
                fillAlpha: 0.12,
                child: Text(
                  node.displayNumber,
                  style: AppTypography.monoSmall
                      .copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.title, style: AppTypography.subtitle),
                    const SizedBox(height: 2),
                    Text(
                      '${node.progressRangeText} · ${node.phaseName}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _intakeCard() {
    final materials = ref.watch(materialsProvider);
    final folderSet = ref.watch(learningRootProvider).isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('阶段 0：输入源建档', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '先锚定今天的输入源 —— 它决定了 AI 拷问的方向。\n'
            '输入源来自你的个性化资源文件夹，勾选后正文会随提问一起发给 AI。',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          _materialsBlock(materials, folderSet),
          const SizedBox(height: AppSpacing.lg),
          Text('补充说明（可选）', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _backgroundController,
            maxLines: 3,
            minLines: 2,
            style: AppTypography.body,
            decoration: const InputDecoration(
              hintText: '文件夹里没有、但今天需要交代的上下文。\n'
                  '例如：这块代码下周要上生产，我负责其中的连接池。',
            ),
          ),
        ],
      ),
    );
  }

  /// 输入源清单 —— 文件夹里扫到的实际文档，不是让用户凭空敲
  Widget _materialsBlock(AsyncValue<List<SourceMaterial>> async, bool folderSet) {
    return async.when(
      loading: () => Text('正在扫描个性化资源…', style: AppTypography.caption),
      // 扫描失败不该拦住开始 —— 降级成纯白板
      error: (_, _) => Text(
        '个性化资源读不出来，本次按纯白板进行。',
        style: AppTypography.caption,
      ),
      data: (materials) {
        if (materials.isEmpty) return _noMaterialsHint(folderSet);

        final selection = _selectionOf(materials);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('输入源', style: AppTypography.label),
                const Spacer(),
                Text(
                  '已选 ${selection.length} / ${materials.length}',
                  style: AppTypography.caption,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final m in materials) _materialRow(m, selection),
          ],
        );
      },
    );
  }

  Widget _materialRow(SourceMaterial m, Set<String> selection) {
    final checked = selection.contains(m.path);

    return InkWell(
      onTap: () => setState(() {
        // 首帧的全选是隐式的，第一次点击要把它落成显式集合再取反
        final next = {...selection};
        if (!next.remove(m.path)) next.add(m.path);
        _selected = next;
      }),
      borderRadius: AppBorders.button,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: checked ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.name, style: AppTypography.body),
                  Text(
                    m.hasContent
                        ? '${m.path} · ${m.content.length} 字'
                        : '${m.path} · 空文档',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 扫不到文档时的说明 —— 分两种：没设文件夹 vs 文件夹里没东西
  Widget _noMaterialsHint(bool folderSet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('输入源', style: AppTypography.label),
        const SizedBox(height: AppSpacing.xs),
        Text(
          folderSet
              ? '个性化资源文件夹里还没有文档。\n'
                  '把笔记、业务背景导出成 .md 或 .txt 放进去，'
                  'AI 就能锚定你的真实场景。'
              : '还没有设置个性化资源文件夹。\n'
                  '选定一个文件夹，里面的笔记和背景资料会自动成为输入源。',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '不设置也能开始 —— 纯白板同样是一次有效的闭环。',
          style: AppTypography.caption,
        ),
        if (!folderSet) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go(AppRouter.storageSettings),
              child: const Text('去设置个性化资源'),
            ),
          ),
        ],
      ],
    );
  }

  void _start(dynamic node, String today) {
    final materials =
        ref.read(materialsProvider).value ?? const <SourceMaterial>[];

    final draft = Checkin(
      date: today,
      trackId: 'cpp',
      nodeId: node.id,
      nodeTitle: node.title,
      // 只存路径，正文在提问时按路径回查 —— 物料改了，提示词跟着改
      materials: _selectionOf(materials).toList()..sort(),
      background: _backgroundController.text.trim(),
    );
    context.go(AppRouter.sopSession, extra: draft);
  }
}
