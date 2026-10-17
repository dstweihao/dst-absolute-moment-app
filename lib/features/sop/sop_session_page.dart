import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/enums/app_enums.dart';
import '../../domain/models/action_card.dart';
import '../../domain/models/checkin.dart';
import '../../domain/models/node.dart';
import '../../domain/models/player_progress.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_card.dart';
import 'domain/difficulty_calibrator.dart';
import 'domain/sop_orchestrator.dart';
import 'widgets/ai_chat_panel.dart';
import 'widgets/stage_indicator.dart';

/// SOP 七阶段会话页 —— APP 的心脏
///
/// 一个全屏的七步向导。铁律：
/// - 禁止跳阶（只能一步步走）
/// - 阶段③ 没有反方证据就锁死「下一步」
/// - 中途退出会提示，防误触丢数据
class SopSessionPage extends ConsumerStatefulWidget {
  const SopSessionPage({super.key});

  @override
  ConsumerState<SopSessionPage> createState() => _SopSessionPageState();
}

class _SopSessionPageState extends ConsumerState<SopSessionPage> {
  static const _orchestrator = SopOrchestrator();
  static const _calibrator = DifficultyCalibrator();

  late Checkin _draft;
  SopStageType _stage = SopStageType.recall;
  Node? _node;

  final _recall1 = TextEditingController();
  final _recall2 = TextEditingController();
  final _recall3 = TextEditingController();
  final _answer = TextEditingController();
  final _assumption = TextEditingController();
  final _translation = TextEditingController();
  final List<_EvidenceControllers> _evidence = [_EvidenceControllers()];

  final _cardWhat = TextEditingController();
  final _cardWhen = TextEditingController();
  final _cardCriteria = TextEditingController();
  final _cardValue = TextEditingController();

  int? _difficulty;
  bool _saving = false;
  bool _initialized = false;
  bool _isFirstSession = false;

  /// 整场会话的总计时（各阶段目标是软性的，不强制中断）
  final Stopwatch _sessionClock = Stopwatch();

  /// 每秒重建一次，让 AppBar 的计时真的在跳 —— Stopwatch 自己不会通知 UI，
  /// 没有这个 timer，「已用 / 目标分钟」在阶段内是冻结的数字。
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _sessionClock.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [
      _recall1, _recall2, _recall3, _answer, _assumption,
      _translation, _cardWhat, _cardWhen, _cardCriteria, _cardValue,
    ]) {
      c.dispose();
    }
    for (final e in _evidence) {
      e.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 首帧时从路由 extra 取草稿，并异步加载节点与历史
    if (!_initialized) {
      final extra = GoRouterState.of(context).extra;
      _draft = extra is Checkin
          ? extra
          : Checkin(date: ref.read(todayStringProvider));
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar(),
        body: Column(
          children: [
            StageIndicator(current: _stage),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.lg,
                  AppSpacing.pageHorizontal,
                  AppSpacing.xl,
                ),
                child: _stageBody(),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 初始化
  // ------------------------------------------------------------------

  Future<void> _bootstrap() async {
    final isFirst = await ref.read(checkinRepositoryProvider).isFirstSession();
    final today = ref.read(todayStringProvider);
    final findings =
        await ref.read(checkinRepositoryProvider).previousFindings(today);

    final nodes = await ref
        .read(nodesProvider(_draft.trackId).future)
        .catchError((_) => <Node>[]);

    Node? node;
    for (final n in nodes) {
      if (n.id == _draft.nodeId) {
        node = n;
        break;
      }
    }

    if (!mounted) return;

    // 回填上一轮的关键发现（阶段⓪ 的提示）
    if (findings.isNotEmpty) {
      _recall1.text = findings[0];
      _recall2.text = findings.length > 1 ? findings[1] : '';
      _recall3.text = findings.length > 2 ? findings[2] : '';
    }

    setState(() {
      _isFirstSession = isFirst;
      _node = node;
      if (node != null && node.questions.isNotEmpty) {
        _draft = _draft.copyWith(
          socraticQuestion: node.questions.first.text,
        );
      }
      if (isFirst) {
        _draft = _draft.copyWith(recallSkipped: true);
      } else {
        // 非首次时清空回填，逼用户凭记忆写
        _recall1.clear();
        _recall2.clear();
        _recall3.clear();
      }
    });
  }

  // ------------------------------------------------------------------
  // 顶部栏
  // ------------------------------------------------------------------

  PreferredSizeWidget _appBar() {
    final elapsed = _sessionClock.elapsed;
    final target = Duration(minutes: _stage.targetMinutes);
    final overtime = elapsed.inMinutes > _stage.targetMinutes;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _confirmExit,
      ),
      title: Text(_stage.label),
      centerTitle: true,
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: overtime ? AppColors.accent : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${elapsed.inMinutes.toString().padLeft(2, '0')}:'
                  '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: AppTypography.monoSmall.copyWith(
                    fontSize: 13,
                    color: overtime
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
                Text(
                  ' / ${target.inMinutes}分',
                  style: AppTypography.label,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 阶段内容
  // ------------------------------------------------------------------

  Widget _stageBody() {
    return switch (_stage) {
      SopStageType.recall => _recallStage(),
      SopStageType.questioning => _questioningStage(),
      SopStageType.breakdown => _breakdownStage(),
      SopStageType.verification => _verificationStage(),
      SopStageType.translation => _translationStage(),
      SopStageType.actionCard => _actionCardStage(),
      SopStageType.selfRating => _selfRatingStage(),
    };
  }

  /// 阶段⓪ 昨日提取
  Widget _recallStage() {
    if (_isFirstSession) {
      return Column(
        children: [
          _banner(
            '首次会话，本阶段自动跳过',
            '从下一轮开始，你需要在进入当日攻坚前，凭记忆写出上轮的 3 个关键发现。',
            AppColors.stageRecall,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '这条规则的作用：不翻笔记的回忆会暴露你真正记住了什么。\n'
            '能想起来的才是你的，想不起来说明那轮白学了。',
            style: AppTypography.caption,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _banner(
          '凭记忆写，不翻任何笔记',
          '写出上轮学习的 3 个关键发现或认知反转。想不起来就写"想不起来"。',
          AppColors.stageRecall,
        ),
        const SizedBox(height: AppSpacing.lg),
        _labeledField('发现 1', _recall1, hint: '上轮我学到的第一件事…'),
        _labeledField('发现 2', _recall2),
        _labeledField('发现 3', _recall3),
      ],
    );
  }

  /// 阶段① 诘问
  Widget _questioningStage() {
    final question = _draft.socraticQuestion.isNotEmpty
        ? _draft.socraticQuestion
        : (_node?.firstQuestion?.text ?? '（本节点暂无诘问）');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _quoteCard('💬 苏格拉底诘问', question, AppColors.stageQuestion),
        const SizedBox(height: AppSpacing.lg),
        _banner(
          '凭第一反应作答，禁止查任何资料',
          '答错没关系 —— 这里的目的就是暴露你真实的理解水平。',
          AppColors.accent,
        ),
        const SizedBox(height: AppSpacing.md),
        _socraticScaffoldBar(_answer, (val) => _draft = _draft.copyWith(userAnswer: val)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _answer,
          maxLines: 8,
          minLines: 5,
          style: AppTypography.body,
          decoration: const InputDecoration(
            hintText: '写下你的直觉答案（可借助上方三层认知维度深入思考）…',
          ),
          onChanged: (v) => _draft = _draft.copyWith(userAnswer: v),
        ),
        if (_stage.allowsAi) ...[
          const SizedBox(height: AppSpacing.lg),
          AiChatPanel(
            // 强制按阶段重建：否则 Flutter 会按位置复用同一个 State，
            // 把上一阶段的对话（以及它的 system 指令）带进下一阶段
            key: ValueKey(_stage),
            stage: _stage,
            node: _node,
            getDraft: _currentDraft,
          ),
        ],
      ],
    );
  }

  /// 三层认知思考脚手架（物理机制 / 边界陷阱 / 架构权衡）
  Widget _socraticScaffoldBar(
    TextEditingController controller,
    void Function(String) onUpdate,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppBorders.card,
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, size: 14, color: AppColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '三层认知引导（点击注入思考锚点）：',
                style: AppTypography.label.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _scaffoldChip(
                label: '底层物理机制',
                prefix: '【底层物理机制】：从内存/编译器视角看，',
                controller: controller,
                onUpdate: onUpdate,
              ),
              _scaffoldChip(
                label: '极端边界陷阱',
                prefix: '【极端边界陷阱】：在空值/越界/并发竞态下，',
                controller: controller,
                onUpdate: onUpdate,
              ),
              _scaffoldChip(
                label: '架构设计权衡',
                prefix: '【设计权衡取舍】：之所以选择该方案而非其他，是因为',
                controller: controller,
                onUpdate: onUpdate,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scaffoldChip({
    required String label,
    required String prefix,
    required TextEditingController controller,
    required void Function(String) onUpdate,
  }) {
    return InkWell(
      borderRadius: AppBorders.badge,
      onTap: () {
        final current = controller.text;
        if (current.contains(prefix)) return;
        final separator = current.trim().isEmpty ? '' : '\n\n';
        final updated = '$current$separator$prefix';
        controller.text = updated;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: updated.length),
        );
        onUpdate(updated);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: AppBorders.badge,
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.accent),
        ),
      ),
    );
  }

  /// 阶段② 拆解
  Widget _breakdownStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _readonlyCard('你的回答', _draft.userAnswer),
        const SizedBox(height: AppSpacing.lg),
        _banner(
          '找出最脆弱的假设',
          '回看你刚才的答案 —— 哪一句话是你最没把握、最经不起追问的？'
              '那就是今日靶心。',
          AppColors.stageBreakdown,
        ),
        const SizedBox(height: AppSpacing.md),
        _socraticScaffoldBar(_assumption, (val) => _draft = _draft.copyWith(weakestAssumption: val)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _assumption,
          maxLines: 6,
          minLines: 4,
          style: AppTypography.body,
          decoration: const InputDecoration(
            hintText: '我答案里最脆弱的假设是（可借助上方三层认知维度反省）…',
          ),
          onChanged: (v) => _draft = _draft.copyWith(weakestAssumption: v),
        ),
        if (_stage.allowsAi) ...[
          const SizedBox(height: AppSpacing.lg),
          AiChatPanel(
            // 强制按阶段重建：否则 Flutter 会按位置复用同一个 State，
            // 把上一阶段的对话（以及它的 system 指令）带进下一阶段
            key: ValueKey(_stage),
            stage: _stage,
            node: _node,
            getDraft: _currentDraft,
          ),
        ],
      ],
    );
  }

  /// 阶段③ 验证 —— 全 APP 最硬的关卡
  Widget _verificationStage() {
    final validCount = _evidence.where((e) => e.isComplete).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _banner(
          '必须找到至少 1 条反方证据',
          '找不到就无法进入阶段④ —— 进度锁死。'
              '这是整轮闭环价值最高的一步：把"我以为"变成"实际上"。',
          AppColors.stageVerify,
        ),
        const SizedBox(height: AppSpacing.lg),

        for (var i = 0; i < _evidence.length; i++) _evidenceBlock(i),

        if (_evidence.length < 5)
          OutlinedButton.icon(
            onPressed: () => setState(() => _evidence.add(_EvidenceControllers())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('再加一条'),
          ),

        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: validCount >= 1
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.surfaceVariant,
            borderRadius: AppBorders.badge,
          ),
          child: Row(
            children: [
              Icon(
                validCount >= 1 ? Icons.check_circle : Icons.warning_amber,
                size: 18,
                color: validCount >= 1
                    ? AppColors.success
                    : AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                validCount >= 1
                    ? '已找到 $validCount 条有效证据'
                    : '尚未找到有效证据（两条都要填完整）',
                style: AppTypography.caption.copyWith(
                  color: validCount >= 1
                      ? AppColors.success
                      : AppColors.accent,
                ),
              ),
            ],
          ),
        ),

        if (_stage.allowsAi) ...[
          const SizedBox(height: AppSpacing.lg),
          AiChatPanel(
            // 强制按阶段重建：否则 Flutter 会按位置复用同一个 State，
            // 把上一阶段的对话（以及它的 system 指令）带进下一阶段
            key: ValueKey(_stage),
            stage: _stage,
            node: _node,
            getDraft: _currentDraft,
          ),
        ],
      ],
    );
  }

  Widget _evidenceBlock(int index) {
    final e = _evidence[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        accentColor: e.isComplete ? AppColors.success : AppColors.stageVerify,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('反方证据 ${index + 1}', style: AppTypography.label),
                const Spacer(),
                if (_evidence.length > 1)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _evidence.removeAt(index);
                        _syncEvidence();
                      });
                    },
                    child: Icon(Icons.close,
                        size: 16, color: AppColors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: e.assumed,
              style: AppTypography.body,
              decoration: InputDecoration(
                labelText: '我原以为…',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              onChanged: (_) => _syncEvidence(),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: e.actual,
              style: AppTypography.body,
              decoration: InputDecoration(
                labelText: '但实际上…',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              onChanged: (_) => _syncEvidence(),
            ),
          ],
        ),
      ),
    );
  }

  /// 阶段④ 转化
  Widget _translationStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _banner(
          '用清晰准确的工程语言阐释机制',
          '不是背八股文，是说清楚"理解了这个底层机制，在排查崩溃或架构设计时有什么关键价值"。',
          AppColors.stageTranslate,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _translation,
          maxLines: 8,
          minLines: 5,
          style: AppTypography.body,
          decoration: const InputDecoration(
            hintText: '例如：\n'
                '该模块在跨线程析构时容易触发野指针或未定义行为，'
                '原因是对象生命周期由各自栈帧决定。改用严格的 RAII 契约后，'
                '从编译器期杜绝悬挂引用，避免生产环境偶发崩溃。',
          ),
          onChanged: (v) => _draft = _draft.copyWith(businessTranslation: v),
        ),
        const SizedBox(height: AppSpacing.lg),
        _selfCheckList(const [
          '逻辑链条完整吗？（因果推导是否严密无漏洞）',
          '讲清物理机制与避坑点了吗？还是只是泛泛而谈？',
          '技术术语是否都给出了精准的物理对应？',
        ]),
        if (_stage.allowsAi) ...[
          const SizedBox(height: AppSpacing.lg),
          AiChatPanel(
            // 强制按阶段重建：否则 Flutter 会按位置复用同一个 State，
            // 把上一阶段的对话（以及它的 system 指令）带进下一阶段
            key: ValueKey(_stage),
            stage: _stage,
            node: _node,
            getDraft: _currentDraft,
          ),
        ],
      ],
    );
  }

  /// 阶段⑤ 行动卡片
  Widget _actionCardStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _banner(
          '输出一张可验证的实践卡片',
          '写一条马上就能去编译器或调试器里验证的操作，四要素缺一不可。',
          AppColors.stageAction,
        ),
        const SizedBox(height: AppSpacing.lg),
        _labeledField('做什么', _cardWhat,
            hint: '例如：在 demo.cpp 里构造一个触发 use-after-free 的最小样例'),
        _labeledField('几点做', _cardWhen, hint: '例如：今天 21:00 前'),
        _labeledField('完成标准', _cardCriteria,
            hint: '例如：用 clang++ -fsanitize=address 编译并成功捕获 ASan 报告'),
        _labeledField('工程验证价值', _cardValue,
            hint: '例如：亲眼见证 AddressSanitizer 捕获影子内存中毒的过程'),
        const SizedBox(height: AppSpacing.lg),
        _selfCheckList(_cardMissing()),
        if (_stage.allowsAi) ...[
          AiChatPanel(
            // 强制按阶段重建：否则 Flutter 会按位置复用同一个 State，
            // 把上一阶段的对话（以及它的 system 指令）带进下一阶段
            key: ValueKey(_stage),
            stage: _stage,
            node: _node,
            getDraft: _currentDraft,
          ),
        ],
      ],
    );
  }

  List<String> _cardMissing() {
    final card = _buildActionCard();
    if (card.isComplete) return const ['四要素已齐全 ✓'];
    return card.missingFields.map((f) => '还缺：$f').toList();
  }

  /// 阶段⑥ 自评
  Widget _selfRatingStage() {
    // 校准必须看历史，否则「连续 N 次过难 → 触发降维支线」这条规则永远不触发。
    // listAll() 返回倒序（新→旧），而校准器要的是**旧→新**的 7 条窗口。
    final today = ref.watch(todayStringProvider);
    final recent = (ref.watch(allCheckinsProvider).value ?? const <Checkin>[])
        .where((c) => c.date != today && c.difficulty != null)
        .map((c) => c.difficulty!)
        .toList()
        .reversed
        .take(DifficultyCalibrator.windowSize)
        .toList()
        .reversed
        .toList();

    final adjustment =
        _difficulty == null ? null : _calibrator.calibrate(_difficulty!, recent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('今天这一关，难度如何？', style: AppTypography.subtitle),
        const SizedBox(height: AppSpacing.lg),
        _difficultySelector(),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('太简单', style: AppTypography.label),
            Text('甜蜜区 3-7', style: AppTypography.label),
            Text('太难', style: AppTypography.label),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          backgroundColor: AppColors.inputBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.track_changes,
                      size: 18, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Text('甜蜜点（3-7 分）', style: AppTypography.subtitle),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '猜对 50-70% 是最佳学习区。\n'
                '太简单说明该加速，太难说明底层有洞、需要降维拆解。',
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
        if (adjustment != null) ...[
          const SizedBox(height: AppSpacing.cardGap),
          AppCard(
            child: Row(
              children: [
                Icon(
                  adjustment.needsSideQuest
                      ? Icons.warning_amber
                      : Icons.trending_up,
                  size: 18,
                  color: adjustment.inSweetSpot
                      ? AppColors.success
                      : AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('明日建议：${adjustment.suggestionText}',
                          style: AppTypography.body),
                      const SizedBox(height: 2),
                      Text(adjustment.rationale,
                          style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _difficultySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 1; i <= 10; i++)
          GestureDetector(
            onTap: () => setState(() => _difficulty = i),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              width: _difficulty == i ? 32 : 26,
              height: _difficulty == i ? 32 : 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _difficulty == i
                    ? _difficultyColor(i)
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
                border: _difficulty == i
                    ? Border.all(color: Colors.white24, width: 2)
                    : null,
              ),
              child: Text(
                '$i',
                style: AppTypography.monoSmall.copyWith(
                  fontSize: _difficulty == i ? 14 : 12,
                  color: _difficulty == i
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _difficultyColor(int score) => switch (DifficultyBand.fromScore(score)) {
        DifficultyBand.tooEasy => AppColors.difficultyTooEasy,
        DifficultyBand.sweetSpot => AppColors.difficultySweetSpot,
        DifficultyBand.tooHard => AppColors.difficultyTooHard,
      };

  // ------------------------------------------------------------------
  // 底部导航
  // ------------------------------------------------------------------

  Widget _bottomBar() {
    final validation = _orchestrator.validate(
      _stage,
      _currentDraft(),
      isFirstSession: _isFirstSession,
    );
    final isLast = _orchestrator.nextStage(_stage) == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!validation.canAdvance) ...[
            Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 14, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    validation.message,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              if (_orchestrator.canGoBack(_stage))
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _goBack,
                      child: const Text('上一阶段'),
                    ),
                  ),
                ),
              if (_orchestrator.canGoBack(_stage))
                const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: (!validation.canAdvance || _saving)
                        ? null
                        : (isLast ? _finish : _goNext),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isLast ? '完成打卡' : '下一步'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 交互
  // ------------------------------------------------------------------

  void _goNext() {
    final next = _orchestrator.nextStage(_stage);
    if (next == null) return;
    setState(() {
      _draft = _currentDraft();
      _stage = next;
    });
  }

  void _goBack() {
    final prev = SopStageType.fromIndex(_stage.index - 1);
    setState(() => _stage = prev);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);

    final finalDraft = _currentDraft().copyWith(
      completed: true,
      durationMinutes: _sessionClock.elapsed.inMinutes,
    );

    final prevLevel = ref.read(playerProgressProvider).value?.level;
    final earnedXp = PlayerProgress.xpForCheckin(finalDraft);

    try {
      await ref.read(checkinRepositoryProvider).save(finalDraft);

      ref.invalidate(allCheckinsProvider);
      ref.invalidate(currentStreakProvider);
      ref.invalidate(longestStreakProvider);
      ref.invalidate(passedNodeIdsProvider);
      ref.invalidate(hasCheckedInTodayProvider);
      ref.invalidate(actionCardsProvider);
      ref.invalidate(overallProgressProvider);
      ref.invalidate(todaysNodeProvider);
      ref.invalidate(playerProgressProvider);

      if (!mounted) return;

      // 通关结算：先给成长反馈，再回看板
      final progress = await _loadProgressSafely();
      if (!mounted) return;

      await _showReward(
        earnedXp: earnedXp,
        progress: progress,
        leveledUp: progress != null &&
            prevLevel != null &&
            progress.level > prevLevel,
      );

      if (!mounted) return;
      context.go(AppRouter.dashboard);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // 写失败必须如实告知，绝不假装成功
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('保存失败'),
          content: Text(
            '本次打卡未保存到坚果云。\n\n$e\n\n'
            '请检查网络后重试。你的内容还在本页，不要退出。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('继续编辑'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _finish();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
  }

  /// 读取最新成长档案；失败返回 null（不阻塞结算流程）
  Future<PlayerProgress?> _loadProgressSafely() async {
    try {
      return await ref.read(playerProgressProvider.future);
    } catch (_) {
      return null;
    }
  }

  /// 通关结算弹层 —— +XP，可能升级
  Future<void> _showReward({
    required int earnedXp,
    required PlayerProgress? progress,
    required bool leveledUp,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 44,
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              leveledUp ? '升级了' : '本关通过',
              style: AppTypography.title,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '+$earnedXp XP',
              style: AppTypography.display.copyWith(
                fontSize: 28,
                color: AppColors.success,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Lv.${progress.level} · ${progress.rankTitle}',
                textAlign: TextAlign.center,
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${progress.xpIntoLevel} / ${progress.xpForNextLevel} XP',
                style: AppTypography.caption,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text('已保存到坚果云 ✓', style: AppTypography.label),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    final elapsed = _sessionClock.elapsed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出本次闭环？'),
        content: Text(
          '已进行 ${elapsed.inMinutes} 分钟，当前内容尚未保存。\n'
          '退出后本次填写将丢失。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续学习'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.go(AppRouter.dashboard);
    }
  }

  void _syncEvidence() {
    final list = _evidence
        .map((e) => CounterEvidence(
              assumed: e.assumed.text.trim(),
              actual: e.actual.text.trim(),
            ))
        .where((e) => e.assumed.isNotEmpty || e.actual.isNotEmpty)
        .toList();
    setState(() => _draft = _draft.copyWith(counterEvidence: list));
  }

  ActionCard _buildActionCard() {
    final today = _draft.date;
    return ActionCard(
      id: 'action-$today',
      sourceDate: today,
      what: _cardWhat.text.trim(),
      whenText: _cardWhen.text.trim(),
      criteria: _cardCriteria.text.trim(),
      businessValue: _cardValue.text.trim(),
    );
  }

  /// 把各输入框的当前值汇聚成一份草稿
  Checkin _currentDraft() {
    var draft = _draft;

    if (!_isFirstSession) {
      final findings = [
        _recall1.text.trim(),
        _recall2.text.trim(),
        _recall3.text.trim(),
      ].where((s) => s.isNotEmpty).toList();
      draft = draft.copyWith(yesterdayFindings: findings);
    }

    draft = draft.copyWith(
      userAnswer: _answer.text.trim(),
      weakestAssumption: _assumption.text.trim(),
      businessTranslation: _translation.text.trim(),
      counterEvidence: _evidence
          .map((e) => CounterEvidence(
                assumed: e.assumed.text.trim(),
                actual: e.actual.text.trim(),
              ))
          .where((e) => e.assumed.isNotEmpty || e.actual.isNotEmpty)
          .toList(),
      actionCard: _buildActionCard(),
      difficulty: _difficulty,
    );

    return draft;
  }

  // ------------------------------------------------------------------
  // 可复用小组件
  // ------------------------------------------------------------------

  Widget _banner(String title, String body, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppBorders.badge,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body
                      .copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(body, style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quoteCard(String label, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppBorders.card,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label.copyWith(color: color)),
          const SizedBox(height: AppSpacing.md),
          Text(text, style: AppTypography.body.copyWith(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _readonlyCard(String label, String text) {
    return AppCard(
      backgroundColor: AppColors.inputBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text.isEmpty ? '（未填写）' : text,
            style: AppTypography.bodyMuted,
          ),
        ],
      ),
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            maxLines: 4,
            minLines: 2,
            style: AppTypography.body,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }

  Widget _selfCheckList(List<String> items) {
    return AppCard(
      backgroundColor: AppColors.inputBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('自检', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('·  ', style: AppTypography.caption),
                  Expanded(
                    child: Text(item, style: AppTypography.caption),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 一条反方证据的两个输入控制器
class _EvidenceControllers {
  final assumed = TextEditingController();
  final actual = TextEditingController();

  bool get isComplete =>
      assumed.text.trim().isNotEmpty && actual.text.trim().isNotEmpty;

  void dispose() {
    assumed.dispose();
    actual.dispose();
  }
}
