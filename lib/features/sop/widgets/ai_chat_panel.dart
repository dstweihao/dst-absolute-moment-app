import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/ai/ai_client.dart';
import '../../../data/ai/prompts/stage_prompts.dart';
import '../../../domain/enums/app_enums.dart';
import '../../../domain/models/checkin.dart';
import '../../../domain/models/node.dart';
import '../../../domain/models/source_material.dart';
import '../../../providers.dart';
import '../../../router.dart';

/// AI 拷问面板 —— 嵌入阶段①②③④⑤
///
/// **这是审校门，不是聊天窗口。** 每个阶段只有一个输入框（阶段自己的答案框），
/// 面板只负责把拆塔官的追问**输出**出来。用户改完答案再点一次按钮，
/// 拆塔官基于新版答案继续拷问。
///
/// 为什么不给面板自己的输入框：那样的对话内容既不落盘、也不进打卡记录，
/// 而且和上面的答案框并列时，用户不知道该写哪一个。答案只能有一个来源 ——
/// 阶段自己的那个框。
///
/// 关键设计：**这是可选增强，不是必经之路。**
/// 未配置 AI、或断网、或调用失败时，用户依然可以直接「下一步」走完七阶段。
class AiChatPanel extends ConsumerStatefulWidget {
  final SopStageType stage;
  final Node? node;

  /// 取**当前**草稿的回调，而不是草稿对象本身。
  ///
  /// 阶段页在 `onChanged` 里就地改 `_draft` 字段、不触发重建，所以传进来的
  /// 对象会在用户继续打字后变旧。发送时现取，才拿得到最新答案。
  final Checkin Function() getDraft;

  const AiChatPanel({
    super.key,
    required this.stage,
    required this.node,
    required this.getDraft,
  });

  @override
  ConsumerState<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends ConsumerState<AiChatPanel> {
  final _scroll = ScrollController();

  final List<AiMessage> _history = [];
  String _streaming = '';
  bool _busy = false;
  String? _error;
  StreamSubscription<AiChunk>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(aiAvailableProvider);

    if (!available) {
      return _unavailableHint();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: AppBorders.card,
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (_history.isEmpty && _streaming.isEmpty)
            _idleHint()
          else
            _conversation(),
          if (_error != null) _errorBar(),
          _actionRow(),
        ],
      ),
    );
  }

  Widget _unavailableHint() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: AppBorders.card,
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined,
              size: 18, color: AppColors.textDisabled),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '配置 AI 后可让拆塔官拷问你',
              style: AppTypography.caption,
            ),
          ),
          TextButton(
            onPressed: () => context.push(AppRouter.aiSettings),
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.gavel, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text('拆塔官', style: AppTypography.subtitle),
          const Spacer(),
          if (_busy)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  /// 还没开过口时的说明 —— 让用户知道这个面板干什么、什么时候按按钮
  Widget _idleHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        '写完后点下面的按钮。拆塔官不会给你答案，只会挑你答案里的毛病。',
        style: AppTypography.caption,
      ),
    );
  }

  Widget _conversation() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView(
        controller: _scroll,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          // 只渲染拆塔官说过的话。用户侧那条是注入的提示词（含输入源全文），
          // 属于实现细节，回显出来只是噪音 —— 用户的答案在上面的答案框里。
          for (final msg in _history)
            if (msg.role == AiRole.assistant) _bubble(msg.content),
          if (_streaming.isNotEmpty)
            _bubble(_streaming, streaming: true),
          if (_busy && _streaming.isEmpty) _thinkingBubble(),
        ],
      ),
    );
  }

  Widget _bubble(String text, {bool streaming = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppBorders.card,
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(text, style: AppTypography.body),
            ),
            if (streaming)
              Text('▌', style: AppTypography.body),
          ],
        ),
      ),
    );
  }

  Widget _thinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text('拆塔官正在思考…', style: AppTypography.caption),
      ),
    );
  }

  Widget _errorBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: AppBorders.badge,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _error!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  /// 唯一的操作入口 —— 把**当前**答案递交拷问
  Widget _actionRow() {
    final started = _history.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        height: 42,
        child: _busy
            ? OutlinedButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('停止'),
              )
            : started
                ? OutlinedButton.icon(
                    onPressed: _send,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('基于修改再拷问'),
                  )
                : ElevatedButton.icon(
                    onPressed: _send,
                    icon: const Icon(Icons.psychology_outlined, size: 18),
                    label: const Text('拷问我的答案'),
                  ),
      ),
    );
  }

  // ------------------------------------------------------------------

  /// 把阶段 0 选定的路径还原成物料正文。
  ///
  /// 打卡记录里只存路径，正文在这里按路径回查 —— 物料被编辑或删掉之后，
  /// 提示词跟着变，不会拿着一份过期副本。路径失效（文件被删）时静默跳过。
  List<SourceMaterial> _resolveMaterials() {
    final paths = widget.getDraft().materials;
    if (paths.isEmpty) return const [];

    final scanned =
        ref.read(materialsProvider).value ?? const <SourceMaterial>[];
    final byPath = {for (final m in scanned) m.path: m};
    return [
      for (final p in paths)
        if (byPath[p] != null) byPath[p]!,
    ];
  }

  Future<void> _send() async {
    final client = ref.read(aiClientProvider);
    if (client == null) {
      setState(() => _error = 'AI 未配置');
      return;
    }

    // 现取草稿 —— 用户刚打的字必须在这一版里
    final draft = widget.getDraft();

    // 空答案交给 AI 拷问只是浪费一次调用，先把话说清楚
    if (!_hasStageContent(widget.stage, draft)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先写下这一阶段的答案，再让拆塔官拷问')),
      );
      return;
    }

    if (_history.isEmpty) {
      // 首轮：给足上下文（人格 + 阶段任务 + 输入源 + 节点 + 答案）
      final settings = ref.read(aiSettingsProvider);
      _history.add(AiMessage.system(
        StagePrompts.system(widget.stage, personaId: settings.persona),
      ));
      _history.add(AiMessage.user(
        StagePrompts.user(
          widget.stage,
          node: widget.node,
          draft: draft,
          materials: _resolveMaterials(),
        ),
      ));
    } else {
      // 后续轮：只发最新答案。输入源与节点上下文上一条还在，
      // 重复发送既费钱，也会让模型把注意力放到背景而不是答案的变化上。
      _history.add(AiMessage.user(
        StagePrompts.userFollowUp(widget.stage, draft),
      ));
    }

    setState(() {
      _busy = true;
      _error = null;
      _streaming = '';
    });

    try {
      final stream = client.streamChat(_history);
      _subscription = stream.listen(
        (chunk) {
          if (!mounted) return;
          if (chunk.isDone) return;
          setState(() => _streaming += chunk.delta);
          _autoScroll();
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error = e is AiException ? e.message : e.toString();
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            if (_streaming.isNotEmpty) {
              _history.add(AiMessage.assistant(_streaming));
              _streaming = '';
            }
            _busy = false;
          });
          _autoScroll();
        },
        cancelOnError: true,
      );
    } on AiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  /// 该阶段是否已经写了东西。
  ///
  /// 只判断「有没有写」，不判断「写得好不好」—— 半成品的证据恰恰最需要被拷问。
  static bool _hasStageContent(SopStageType stage, Checkin d) =>
      switch (stage) {
        SopStageType.questioning => d.userAnswer.trim().isNotEmpty,
        SopStageType.breakdown => d.weakestAssumption.trim().isNotEmpty,
        SopStageType.verification => d.counterEvidence.any(
            (e) => e.assumed.trim().isNotEmpty || e.actual.trim().isNotEmpty),
        SopStageType.translation => d.businessTranslation.trim().isNotEmpty,
        SopStageType.actionCard => _cardStarted(d),
        _ => false,
      };

  static bool _cardStarted(Checkin d) {
    final c = d.actionCard;
    if (c == null) return false;
    return c.what.trim().isNotEmpty ||
        c.whenText.trim().isNotEmpty ||
        c.criteria.trim().isNotEmpty ||
        c.businessValue.trim().isNotEmpty;
  }

  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
    ref.read(aiClientProvider)?.cancel();
    setState(() {
      if (_streaming.isNotEmpty) {
        _history.add(AiMessage.assistant(_streaming));
        _streaming = '';
      }
      _busy = false;
    });
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
      );
    });
  }
}
