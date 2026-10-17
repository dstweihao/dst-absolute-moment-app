import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/ai/ai_client.dart';
import '../../data/ai/prompts/personas.dart';
import '../../data/ai/sensitive_content_guard.dart';
import '../../domain/models/node.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_logo.dart';

class LearnPage extends ConsumerStatefulWidget {
  const LearnPage({super.key});

  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  static const String _kStorageKey = 'absolute_moment_active_chat_v1';

  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<AiMessage> _history = [];
  String _streaming = '';
  bool _busy = false;
  String? _error;
  StreamSubscription<AiChunk>? _subscription;
  final Set<String> _passedNodeIds = {};
  final Map<String, double> _nodeProgressMap = {};
  Node? _currentNode;
  double _nodeProgress = 0.0; // 0.0 ~ 1.0
  bool _isRecordingVoice = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final passedList = prefs.getStringList('absolute_moment_passed_nodes_v1');
      if (passedList != null) {
        _passedNodeIds.addAll(passedList);
      }

      for (final key in prefs.getKeys()) {
        if (key.startsWith('node_progress_')) {
          final nid = key.substring('node_progress_'.length);
          final p = prefs.getDouble(key);
          if (p != null) {
            _nodeProgressMap[nid] = p;
          }
        }
      }

      final activeNodeId = prefs.getString('absolute_moment_active_node_id');
      if (activeNodeId != null && activeNodeId.isNotEmpty) {
        ref.read(activeLearningNodeIdProvider.notifier).select(activeNodeId);
      }
      final raw = (activeNodeId != null && activeNodeId.isNotEmpty)
          ? (prefs.getString('node_chat_$activeNodeId') ?? prefs.getString(_kStorageKey))
          : prefs.getString(_kStorageKey);

      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map<AiMessage>((item) {
              final role = item['role'] == 'user'
                  ? AiRole.user
                  : item['role'] == 'assistant'
                      ? AiRole.assistant
                      : AiRole.system;
              final content = (item['content'] ?? '') as String;
              return AiMessage(role, content);
            })
            .toList();
        if (mounted && list.isNotEmpty) {
          setState(() {
            _history.addAll(list);
          });
          _restoreCurrentNodeProgress();
          _autoScroll();
          return;
        }
      }
    } catch (_) {}

    if (mounted && _history.isEmpty) {
      final node = ref.read(todaysNodeProvider).value;
      _currentNode = node;
      _restoreCurrentNodeProgress();
      final title = node?.title ?? '第一个程序';
      final number = node?.displayNumber ?? '01';
      final question = node?.firstQuestion?.text ??
          '在现代 C++ 中，int main() 的返回值传递给了谁？若省略 return 0，底层汇编和操作系统究竟如何处理？';

      setState(() {
        _history.add(AiMessage.assistant(
          '第 $number 关 · $title\n\n$question',
        ));
      });
      _persistHistory(node?.id);
    }
  }

  Future<void> _restoreCurrentNodeProgress([Node? targetNode]) async {
    final node = targetNode ?? _currentNode ?? ref.read(todaysNodeProvider).value;
    if (node == null) return;
    _currentNode = node;

    if (_passedNodeIds.contains(node.id)) {
      _nodeProgressMap[node.id] = 1.0;
      if (mounted) setState(() => _nodeProgress = 1.0);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      double p = prefs.getDouble('node_progress_${node.id}') ?? 0.0;
      // 纠正清洗历史遗留的虚假 15% 起步分：未通关且 <= 15% 时，坚决清零归位
      if (p <= 0.15) {
        p = 0.0;
        await prefs.setDouble('node_progress_${node.id}', 0.0);
      }
      _nodeProgressMap[node.id] = p;
      if (mounted) setState(() => _nodeProgress = p.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> _persistHistory([String? explicitNodeId]) async {
    final nid = explicitNodeId ??
        _currentNode?.id ??
        ref.read(activeLearningNodeIdProvider) ??
        'cpp-01';
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _history
          .map((m) => {
                'role': m.role == AiRole.user
                    ? 'user'
                    : m.role == AiRole.assistant
                        ? 'assistant'
                        : 'system',
                'content': m.content,
              })
          .toList();
      final encoded = jsonEncode(data);
      await prefs.setString(_kStorageKey, encoded);
      if (nid.isNotEmpty) {
        await prefs.setString('node_chat_$nid', encoded);
        await prefs.setString('absolute_moment_active_node_id', nid);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final aiReady = ref.watch(aiAvailableProvider);
    final allNodes = ref.watch(nodesProvider(ref.watch(activeTrackIdProvider))).value ?? const <Node>[];
    final todayNode = ref.watch(todaysNodeProvider).value;
    final activeId = ref.watch(activeLearningNodeIdProvider);
    final activeNode = (activeId != null && allNodes.isNotEmpty)
        ? allNodes.where((n) => n.id == activeId).firstOrNull
        : null;

    final resolvedNode = _currentNode ??
        activeNode ??
        todayNode ??
        (allNodes.isNotEmpty
            ? allNodes.firstWhere((n) => !_passedNodeIds.contains(n.id), orElse: () => allNodes.first)
            : null);

    if (_currentNode == null && resolvedNode != null) {
      _currentNode = resolvedNode;
      _restoreCurrentNodeProgress(resolvedNode);
    }

    ref.listen<String?>(activeLearningNodeIdProvider, (prev, next) {
      if (next != null && next != _currentNode?.id && allNodes.isNotEmpty) {
        final target = allNodes.where((n) => n.id == next).firstOrNull;
        if (target != null) {
          _switchToNode(target);
        }
      }
    });

    final node = _currentNode ?? resolvedNode;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildTrackDrawer(context, allNodes),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 24, color: Color(0xFF1E293B)),
            tooltip: '38 关学习目录',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          '绝对时刻',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22, color: Color(0xFF1E293B)),
            tooltip: '设置',
            onPressed: () => context.push(AppRouter.aiSettings),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!aiReady) _configBanner(),
            Expanded(
              child: _history.isEmpty && _streaming.isEmpty
                  ? _buildWelcomeCenter(node)
                  : _buildConversation(allNodes),
            ),
            if (_error != null) _errorBar(),
            _buildModernInputCard(node, allNodes),
          ],
        ),
      ),
    );
  }



  // ------------------------------------------------------------------
  // 中央欢迎态
  // ------------------------------------------------------------------

  Widget _buildWelcomeCenter(Node? node) {
    final title = node?.title ?? '第一个程序';
    final number = node?.displayNumber ?? '01';
    final question = node?.firstQuestion?.text ??
        '在现代 C++ 中，int main() 的返回值传递给了谁？若省略 return 0，底层汇编和操作系统究竟如何处理？';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildWhaleLogo(),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              '欢迎回来，随时开始推导',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '第 $number 关 · $title',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '今日攻坚',
                        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    question,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton.icon(
                    onPressed: () => _startWithNode(node),
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('开始作答推导'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhaleLogo() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const AppLogo(size: 42),
    );
  }

  // ------------------------------------------------------------------
  // 对话列表
  // ------------------------------------------------------------------

  Widget _buildConversation(List<Node> allNodes) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
      children: [
        for (final msg in _history)
          if (msg.role != AiRole.system) _buildBubble(msg),
        if (_streaming.isNotEmpty)
          _buildBubble(AiMessage.assistant(_streaming), streaming: true),
        if (_busy && _streaming.isEmpty) _buildThinkingIndicator(),
      ],
    );
  }

  Widget _buildBubble(AiMessage msg, {bool streaming = false}) {
    final isUser = msg.role == AiRole.user;

    // 清洗内部掌握度标记 [PROGRESS: xx%]，并拆分思考内容与正式回答
    final raw = msg.content
        .replaceAll(RegExp(r'\[PROGRESS:\s*\d+%?\]', caseSensitive: false), '')
        .trim();

    String? thinking;
    String cleanContent = raw;

    if (!isUser) {
      final thinkMatch = RegExp(r'<think>([\s\S]*?)<\/think>', caseSensitive: false).firstMatch(raw);
      if (thinkMatch != null) {
        thinking = thinkMatch.group(1)?.trim();
        cleanContent = raw.replaceFirst(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '').trim();
      } else {
        final openMatch = RegExp(r'<think>([\s\S]*)$', caseSensitive: false).firstMatch(raw);
        if (openMatch != null) {
          thinking = openMatch.group(1)?.trim();
          cleanContent = '';
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF165DFF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF165DFF).withValues(alpha: 0.16),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(5),
              child: const AppLogo(size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 18),
                ),
                border: isUser ? null : Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
                boxShadow: isUser
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser && thinking != null && thinking.isNotEmpty)
                    _DeepSeekThinkingCard(
                      thinking: thinking,
                      isStreaming: streaming && cleanContent.isEmpty,
                    ),
                  if (cleanContent.isNotEmpty)
                    MarkdownBody(
                      data: cleanContent,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        blockSpacing: 14.0,
                        p: TextStyle(
                          fontSize: 15.0,
                          height: 1.68,
                          color: isUser ? Colors.white : const Color(0xFF1E293B),
                          letterSpacing: 0.1,
                        ),
                        strong: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.0,
                          color: isUser ? Colors.white : const Color(0xFF0F172A),
                        ),
                        h1: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: isUser ? Colors.white : const Color(0xFF0F172A),
                        ),
                        h2: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: isUser ? Colors.white : const Color(0xFF0F172A),
                        ),
                        h3: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: isUser ? Colors.white : const Color(0xFF1E293B),
                        ),
                        code: TextStyle(
                          fontSize: 13.5,
                          color: isUser ? Colors.white : const Color(0xFF0F172A),
                          backgroundColor: isUser
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFFF1F5F9),
                          fontFamily: 'Menlo, Monaco, "Courier New", monospace',
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        codeblockPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        blockquote: TextStyle(
                          fontSize: 14.5,
                          height: 1.6,
                          color: isUser ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF475569),
                        ),
                        blockquotePadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                        blockquoteDecoration: BoxDecoration(
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFF8FAFC),
                          border: Border(
                            left: BorderSide(
                              color: isUser ? Colors.white70 : const Color(0xFF165DFF),
                              width: 3.5,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        listBullet: TextStyle(
                          color: isUser ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (!isUser && !streaming && cleanContent.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: cleanContent));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已复制内容至剪贴板'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: const [
                                Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                                SizedBox(width: 4),
                                Text(
                                  '复制',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!isUser &&
                      (msg.content.contains('尚未配置 DeepSeek API Key') ||
                          msg.content.contains('API Key 无效或鉴权失败'))) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => context.push(AppRouter.aiSettings),
                      icon: const Icon(Icons.key_rounded, size: 16),
                      label: const Text('前往设置 DeepSeek Key'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF165DFF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF165DFF).withValues(alpha: 0.16),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(5),
            child: const AppLogo(size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  'DeepSeek-R1 正在深入推导汇编与内存机制…',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 底部极简科技输入卡片（普通输入 / DeepSeek 原地录音栏）
  // ------------------------------------------------------------------

  Widget _buildModernInputCard(Node? node, List<Node> allNodes) {
    if (_isRecordingVoice) {
      return _buildDeepSeekVoiceBar(node, allNodes);
    }

    final hasText = _input.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              enabled: !_busy,
              style: const TextStyle(fontSize: 15.5, height: 1.45),
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              textAlignVertical: TextAlignVertical.center,
              decoration: const InputDecoration(
                hintText: '输入你的推导与作答…',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              ),
              onSubmitted: (_) => _sendText(null, allNodes),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _isRecordingVoice = true),
            borderRadius: BorderRadius.circular(20),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.mic_none_rounded,
                size: 22,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _busy
                ? _cancel
                : (hasText ? () => _sendText(null, allNodes) : null),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _busy
                    ? AppColors.danger
                    : (hasText ? AppColors.primary : const Color(0xFFE2E8F0)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _busy ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                size: 20,
                color: _busy || hasText ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// DeepSeek 风格极简原地录音栏（波形声浪、取消、完成）
  Widget _buildDeepSeekVoiceBar(Node? node, List<Node> allNodes) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧：取消录音
          InkWell(
            onTap: () => setState(() => _isRecordingVoice = false),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 10),
          // 中间：DeepSeek 律动动态声波条与正在聆听
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DeepSeekWaveBars(),
                SizedBox(width: 10),
                Text(
                  '正在聆听推导…',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 右侧：完成发送按钮
          InkWell(
            onTap: () {
              setState(() => _isRecordingVoice = false);
              if (_input.text.trim().isNotEmpty) {
                _sendText(null, allNodes);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 侧边 38 关课程目录抽屉（简洁清晰，无多余废话）
  // ------------------------------------------------------------------

  Widget _buildTrackDrawer(BuildContext context, List<Node> all) {
    final activeNode = _currentNode ??
        (all.isNotEmpty
            ? all.firstWhere((n) => !_passedNodeIds.contains(n.id), orElse: () => all.first)
            : null);
    final activeId = activeNode?.id ?? (all.isNotEmpty ? all.first.id : '');

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text('38 关标准路线', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: all.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: all.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16),
                      itemBuilder: (ctx, i) {
                        final n = all[i];
                        final isPassed = _passedNodeIds.contains(n.id);
                        final isUnlocked = i == 0 || _passedNodeIds.contains(all[i - 1].id);
                        final isCurrent = (n.id == activeId);
                        final progressValue = isPassed
                            ? 1.0
                            : (_nodeProgressMap[n.id] ?? (isCurrent ? _nodeProgress : 0.0));

                        return ListTile(
                          dense: true,
                          enabled: isUnlocked,
                          leading: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isPassed
                                  ? const Color(0xFF00B42A).withValues(alpha: 0.12)
                                  : isCurrent
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : const Color(0xFF94A3B8).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: isPassed
                                ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF00B42A))
                                : Text(
                                    n.displayNumber,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isUnlocked ? AppColors.primary : const Color(0xFF94A3B8),
                                    ),
                                  ),
                          ),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
                              color: isUnlocked ? null : const Color(0xFF94A3B8),
                            ),
                          ),
                          subtitle: Text(
                            isPassed ? '已掌握' : (isUnlocked ? n.phaseName : '未解锁'),
                            style: AppTypography.caption,
                          ),
                          trailing: isPassed
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00B42A).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '100% ✓',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF00B42A),
                                    ),
                                  ),
                                )
                              : (isCurrent
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '掌握度 ${(progressValue * 100).toInt()}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : (isUnlocked
                                      ? const Icon(Icons.chevron_right_rounded, size: 18)
                                      : const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF94A3B8)))),
                          onTap: () {
                            if (!isUnlocked) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('第 ${n.displayNumber} 关尚未解锁'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            Navigator.of(context).pop();
                            _switchToNode(n);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 对话交互 & AI 掌握度评判自动解锁
  // ------------------------------------------------------------------

  Future<void> _switchToNode(Node? node) async {
    if (node == null) return;

    // 若点击的正是当前正在学习的关卡：绝对不重置，保持当前对话！
    final currentId = _currentNode?.id ?? ref.read(activeLearningNodeIdProvider);
    if (currentId == node.id && _history.isNotEmpty) {
      _currentNode ??= node;
      return;
    }

    // 1. 持久化当前关卡的历史（显式带上 ID，绝不丢失）
    if (currentId != null && currentId.isNotEmpty) {
      await _persistHistory(currentId);
    }

    _subscription?.cancel();
    setState(() {
      _currentNode = node;
      _history.clear();
      _streaming = '';
      _busy = false;
      _error = null;
    });

    ref.read(activeLearningNodeIdProvider.notifier).select(node.id);

    // 2. 加载目标关卡的独立历史
    await _loadHistoryForNode(node);
  }

  Future<void> _loadHistoryForNode(Node n) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('absolute_moment_active_node_id', n.id);

      // 优先读取独立历史；若为空且该关卡即为当前全局活跃关卡，则从旧全局 key 迁移，绝不丢弃数据
      String? raw = prefs.getString('node_chat_${n.id}');
      if (raw == null || raw.isEmpty) {
        final activeSaved = prefs.getString('absolute_moment_active_node_id');
        if (activeSaved == n.id || activeSaved == null) {
          raw = prefs.getString(_kStorageKey);
        }
      }

      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map<AiMessage>((item) {
              final role = item['role'] == 'user'
                  ? AiRole.user
                  : item['role'] == 'assistant'
                      ? AiRole.assistant
                      : AiRole.system;
              final content = (item['content'] ?? '') as String;
              return AiMessage(role, content);
            })
            .toList();

        if (mounted && list.isNotEmpty) {
          setState(() {
            _history.clear();
            _history.addAll(list);
          });
          _restoreCurrentNodeProgress(n);
          _autoScroll();
          return;
        }
      }
    } catch (_) {}

    // 仅在首次进入且历史确实为空时：才注入该关卡第一问，不执行任何清空
    if (mounted && _history.isEmpty) {
      final title = n.title;
      final number = n.displayNumber;
      final question = n.firstQuestion?.text ??
          '在现代 C++ 中，int main() 的返回值传递给了谁？若省略 return 0，底层汇编和操作系统究竟如何处理？';

      setState(() {
        _history.add(AiMessage.assistant(
          '第 $number 关 · $title\n\n$question',
        ));
      });
      _restoreCurrentNodeProgress(n);
      _persistHistory(n.id);
    }
  }

  void _startWithNode(Node? node) {
    if (node != null) {
      _switchToNode(node);
    }
  }

  Future<void> _sendText(String? preset, List<Node> allNodes) async {
    if (_busy) return;

    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;

    // 前置合规防线：针对粗口/违禁/敏感词给出正常说明，绝不报错说成断网或Key失效
    if (SensitiveContentGuard.isSensitive(text)) {
      _history.add(AiMessage.user(text));
      _input.clear();
      setState(() {
        _busy = false;
        _error = null;
        _streaming = '';
        _history.add(AiMessage.assistant(
          SensitiveContentGuard.friendlyWarningMessage(),
        ));
      });
      _autoScroll();
      _persistHistory();
      return;
    }

    final client = ref.read(aiClientProvider);

    _history.add(AiMessage.user(text));
    _input.clear();
    setState(() {
      _busy = true;
      _error = null;
      _streaming = '';
    });
    _autoScroll();
    _persistHistory();

    if (client == null) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _history.add(AiMessage.assistant(
          '⚠️ 尚未配置 DeepSeek API Key\n\n'
          '👉 请点击下方按钮或右上角设置图标 (⚙️) 填写您的 API Key。',
        ));
        _busy = false;
      });
      _autoScroll();
      _persistHistory();
      return;
    }

    final settings = ref.read(aiSettingsProvider);
    final sysMsg = AiMessage.system(_systemPrompt(settings.persona));
    final sendList = <AiMessage>[
      sysMsg,
      ..._history.where((m) => m.role != AiRole.system),
    ];

    try {
      _subscription = client.streamChat(sendList).listen(
        (chunk) {
          if (!mounted || chunk.isDone) return;
          setState(() => _streaming += chunk.delta);
          _autoScroll();
        },
        onError: (Object e) {
          if (!mounted) return;
          final errorMsg = _formatAiError(e);
          setState(() {
            _busy = false;
            _error = errorMsg;
            _history.add(AiMessage.assistant(errorMsg));
          });
          _autoScroll();
          _persistHistory();
        },
        onDone: () {
          if (!mounted) return;
          final fullReply = _streaming;
          setState(() {
            if (_streaming.isNotEmpty) {
              _history.add(AiMessage.assistant(_streaming));
              _streaming = '';
            }
            _busy = false;
          });
          _autoScroll();
          _persistHistory();

          // 解析 AI 的掌握度评分 [PROGRESS: xx%]
          _evaluateAiProgress(fullReply, allNodes);
        },
        cancelOnError: true,
      );
    } catch (e) {
      final errorMsg = _formatAiError(e);
      setState(() {
        _busy = false;
        _error = errorMsg;
        _history.add(AiMessage.assistant(errorMsg));
      });
      _autoScroll();
      _persistHistory();
    }
  }

  String _formatAiError(Object e) {
    if (e is AiException) {
      switch (e.kind) {
        case AiErrorKind.notConfigured:
          return '⚠️ 尚未配置 DeepSeek API Key\n\n'
              '👉 请点击下方按钮或右上角设置图标 (⚙️) 填写您的 API Key。';
        case AiErrorKind.unauthorized:
          return '⚠️ API Key 无效或鉴权失败\n\n'
              '👉 请检查填写的 DeepSeek API Key 是否正确有效。';
        case AiErrorKind.contentFilter:
          return '⚠️ 内容触发安全审查或敏感词过滤\n\n'
              '👉 输入内容可能包含不当用语、违禁词或敏感表达，已被系统拦截。请调整表述，使用理性的技术术语重新输入。';
        case AiErrorKind.rateLimited:
          return '⚠️ 官方服务频次超限或额度不足\n\n'
              '👉 DeepSeek 服务调用过于频繁或账户余额已耗尽，请稍后重试或检查账户额度。';
        case AiErrorKind.modelNotFound:
          return '⚠️ 找不到指定的模型\n\n'
              '👉 请在设置中确认选择的模型（如 deepseek-chat）是否存在。';
        case AiErrorKind.network:
          return '⚠️ 网络连接异常\n\n'
              '👉 无法连接到 AI 服务，请检查本地网络连接或代理设置。';
        case AiErrorKind.server:
          return '⚠️ AI 服务端暂时繁忙\n\n'
              '👉 服务端返回错误，请稍后重新提问。';
        case AiErrorKind.badRequest:
          return '⚠️ 请求无法处理\n\n'
              '👉 ${e.detail.isNotEmpty ? e.detail : '请求格式不被支持，请检查输入。'}';
        case AiErrorKind.malformedResponse:
        case AiErrorKind.cancelled:
        case AiErrorKind.unknown:
          return '⚠️ 调用异常：${e.message}${e.detail.isNotEmpty ? '\n\n详情：${e.detail}' : ''}';
      }
    }
    return '⚠️ 发送失败：$e';
  }

  /// 解析 AI 给出的掌握度评级，达到 100% 自动解锁下一关
  Future<void> _evaluateAiProgress(String reply, List<Node> allNodes) async {
    final match = RegExp(r'\[PROGRESS:\s*(\d+)%?\]', caseSensitive: false).firstMatch(reply);
    if (match != null) {
      final score = int.tryParse(match.group(1) ?? '0') ?? 0;

      // 1. 无效回答坚决不给分（回答“不知道/不会/报错”时，强制锁定 0%）
      final userMsgs = _history.where((m) => m.role == AiRole.user).toList();
      if (userMsgs.isNotEmpty) {
        final lastText = userMsgs.last.content.trim().toLowerCase();
        const vagueTokens = [
          '不知道', '不会', '不清楚', '报错', '没看懂', '不晓得', '没有', '没想法', '求教', '怎么做', '啥', '啥意思', '不明白'
        ];
        final isVague = vagueTokens.any((kw) => lastText.contains(kw)) || lastText.length <= 3;
        if (isVague) {
          return;
        }
      }

      // 2. 单次递增防暴涨保护（平滑梯级成长）：
      // 除非达到 100% 彻底通关，否则单次有效对话递增不超过 10%
      final targetProg = (score / 100.0).clamp(0.0, 1.0);
      if (targetProg <= _nodeProgress) {
        return;
      }

      final double newProg;
      if (targetProg >= 1.0) {
        newProg = 1.0;
      } else {
        const double maxStep = 0.10; // 单步最多递增 10%
        newProg = (_nodeProgress + maxStep < targetProg)
            ? (_nodeProgress + maxStep)
            : targetProg;
      }

      if (newProg > _nodeProgress) {
        setState(() {
          _nodeProgress = newProg;
        });

        final current = _currentNode ?? (allNodes.isNotEmpty ? allNodes.first : null);
        if (current != null) {
          _nodeProgressMap[current.id] = newProg;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('node_progress_${current.id}', _nodeProgress);
          } catch (_) {}
        }
      }

      // 若达到 100% 掌握度：自动解锁并平滑切换进入下一关
      if (newProg >= 1.0) {
        final current = _currentNode ?? (allNodes.isNotEmpty ? allNodes.first : null);
        if (current != null) {
          await _handleAutoUnlock(current, allNodes);
        }
      }
    }
  }

  Future<void> _handleAutoUnlock(Node current, List<Node> allNodes) async {
    _passedNodeIds.add(current.id);
    _nodeProgress = 1.0;
    _nodeProgressMap[current.id] = 1.0;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('absolute_moment_passed_nodes_v1', _passedNodeIds.toList());
      await prefs.setDouble('node_progress_${current.id}', 1.0);
    } catch (_) {}

    if (!mounted) return;

    final currentIndex = allNodes.indexWhere((n) => n.id == current.id);
    final hasNext = currentIndex != -1 && currentIndex + 1 < allNodes.length;

    if (hasNext) {
      final next = allNodes[currentIndex + 1];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('掌握度达到 100%！已自动解锁第 ${next.displayNumber} 关 · ${next.title}'),
          duration: const Duration(seconds: 2),
        ),
      );

      // 平滑延迟后自动开启下一关
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        _startWithNode(next);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已完成全部 38 关的终极推导！'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _systemPrompt(String personaId) {
    final base = Personas.systemPromptFor(personaId);
    final node = _currentNode ?? ref.read(todaysNodeProvider).value;
    final title = node?.title ?? '第一个程序';
    final number = node?.displayNumber ?? '01';
    final coreConcept = node?.coreConcepts.isNotEmpty == true ? node!.coreConcepts.first : '程序入口与底层退出机制';

    return '''
$base

【当前考核任务】：
- 考核关卡：第 $number 关 · $title
- 核心考查点：$coreConcept

【最高执行铁律 · 绝不可违背】：
1. 【绝不直接公布答案，绝不长篇大论灌输】：
   - 严禁直接给出最终结论或完整代码！严禁在英文术语后加括号中文翻译（严禁诸如 executable(可执行文件) 这类割裂表达）！
   - 语言犀利、透彻、直戳要害，绝不客套寒暄！
2. 【遵循 DeepSeek 官方纯正、自然、深度的工程师级 Markdown 风格 · 极度精炼 (Sacrifice grammar for concision)】：
   - 严禁输出“🎯 认知断层”、“⚙️ 底层现实”、“⚡ 核心反诘”等生硬机械的八股文假标签！
   - 【语言密度至上】：为了极致精炼，允许牺牲语法修辞。严禁任何口头禅、连词铺垫（绝不讲“你说得不对”、“这就是问题所在”、“那么问题来了”等废话）。
   - 【直击核心矛盾】：开篇直接戳破直觉猜测与底层物理事实的本质断层，短句直陈。
   - 【展开物理现实】：直接列出物理实体与状态突变（如 ASCII 文本 -> 汇编 -> 二进制 -> 内存地址空间），命令结合行内注释，绝不讲故事。
   - 【单点致命反诘】：末尾只抛出 1 个致命反诘追问，直戳核心实体或寄存器参数，逼迫学员自己把闭环推导出来。
   - 【标点规范】：引用必须使用中文双引号“……”（如“cpp 文件”），严禁半角英文双引号 "..."；文件名代码使用反引号（如 `hello.cpp`）。
3. 【末尾独立行输出掌握度标记】：
   [PROGRESS: <0-100>%]
   - 学员刚开始提问、困惑疑惑、或直觉猜测未切入物理现实底层：严禁给起步虚分，必须输出 [PROGRESS: 0%]！
   - 学员初步触及表层概念或标准规范定义：[PROGRESS: 30%]
   - 学员深入推导触及硬件物理现实（寄存器 EAX/RAX、指令周期、内核系统调用）：[PROGRESS: 65%] ~ [PROGRESS: 80%]
   - 学员将汇编/寄存器/操作系统内核链路严密闭环推导完毕：[PROGRESS: 100%]（触发自动通关）
''';
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
    _persistHistory();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _configBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '当前为基础离线模式。配置 DeepSeek Key 开启实时反诘考核',
              style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
            ),
            onPressed: () => context.push(AppRouter.aiSettings),
            child: const Text('去配置', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _errorBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      color: AppColors.danger.withValues(alpha: 0.1),
      child: Text(
        _error!,
        style: AppTypography.caption.copyWith(color: AppColors.danger),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// DeepSeek 风格极简灵动声波动画（4 根跳动音柱）
class _DeepSeekWaveBars extends StatefulWidget {
  const _DeepSeekWaveBars();

  @override
  State<_DeepSeekWaveBars> createState() => _DeepSeekWaveBarsState();
}

class _DeepSeekWaveBarsState extends State<_DeepSeekWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bar(8 + val * 8),
            const SizedBox(width: 3),
            _bar(16 - val * 8),
            const SizedBox(width: 3),
            _bar(10 + val * 10),
            const SizedBox(width: 3),
            _bar(18 - val * 9),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3.5,
      height: height.clamp(4.0, 20.0),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _DeepSeekThinkingCard extends StatefulWidget {
  final String thinking;
  final bool isStreaming;

  const _DeepSeekThinkingCard({
    required this.thinking,
    this.isStreaming = false,
  });

  @override
  State<_DeepSeekThinkingCard> createState() => _DeepSeekThinkingCardState();
}

class _DeepSeekThinkingCardState extends State<_DeepSeekThinkingCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isStreaming;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thinking.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    widget.isStreaming ? Icons.psychology_rounded : Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isStreaming ? '正在深度思考…' : '已深度思考',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFCBD5E1), width: 2),
                  ),
                ),
                child: Text(
                  widget.thinking,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: Color(0xFF64748B),
                    fontFamily: 'Menlo, Monaco, monospace',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

