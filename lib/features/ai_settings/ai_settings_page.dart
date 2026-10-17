import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../data/ai/provider_presets.dart';
import '../../domain/enums/app_enums.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/node.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/back_leading.dart';

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  final _apiKey = TextEditingController();
  bool _busy = false;
  bool _obscureKey = true;
  bool _configLoaded = false;
  bool _keyLoaded = false;
  int _passedCount = 0;

  bool _loadingBalance = false;
  bool? _balanceAvailable;
  String? _totalBalance;
  String? _grantedBalance;
  String? _toppedUpBalance;
  String? _balanceError;

  @override
  void initState() {
    super.initState();
    _loadPassedCount();
  }

  Future<void> _loadPassedCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('absolute_moment_passed_nodes_v1') ?? [];
      if (mounted) {
        setState(() {
          _passedCount = list.length;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final savedKey = ref.watch(aiApiKeyProvider);
    final aiSettings = ref.watch(aiSettingsProvider);
    final allNodes = ref.watch(nodesProvider(ref.watch(activeTrackIdProvider))).value ?? const <Node>[];
    final totalNodes = allNodes.isNotEmpty ? allNodes.length : 38;

    final rawModel = aiSettings.model.trim();
    final modelName = rawModel.isNotEmpty
        ? rawModel
        : (presetById('deepseek')?.model ?? 'deepseek-reasoner');

    if (!_configLoaded && config.hasValue) {
      _configLoaded = true;
    }

    if (!_keyLoaded && savedKey.hasValue) {
      final k = savedKey.value ?? '';
      _apiKey.text = k;
      _keyLoaded = true;
      if (k.isNotEmpty) {
        _fetchDeepSeekBalance(k);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const PageBackButton(fallback: AppRouter.learn),
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // 第一部分：总的学习统计
            _buildSectionHeader('学习统计', Icons.insights_rounded),
            const SizedBox(height: 12),
            _buildStatsCard(totalNodes),
            const SizedBox(height: 28),

            // 第二部分：Key 的设置
            _buildSectionHeader('API Key 设置', Icons.key_rounded),
            const SizedBox(height: 12),
            _buildKeyCard(modelName),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        '保存',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(int totalNodes) {
    final progressPercent = totalNodes > 0 ? (_passedCount / totalNodes * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'C++ 38 关进阶路线',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已攻克 $_passedCount 关 / 共 $totalNodes 关',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$progressPercent%',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalNodes > 0 ? (_passedCount / totalNodes).clamp(0.0, 1.0) : 0.0,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  '已掌握',
                  '$_passedCount 关',
                  const Color(0xFF00B42A),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildMetricItem(
                  '待突破',
                  '${(totalNodes - _passedCount).clamp(0, totalNodes)} 关',
                  const Color(0xFF64748B),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildMetricItem(
                  '通关率',
                  '$progressPercent%',
                  AppColors.primary,
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildMetricItem(
                  '1 个小时',
                  '${(totalNodes - _passedCount).clamp(0, totalNodes)} 天',
                  const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildKeyCard(String modelName) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.key_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                'DeepSeek API Key',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B42A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  modelName.isNotEmpty ? modelName : 'deepseek-reasoner',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF00B42A), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKey,
            obscureText: _obscureKey,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'sk-xxxxxxxxxxxxxxxxxxxxxxxx',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: const Color(0xFF94A3B8),
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildBalanceBar(),
        ],
      ),
    );
  }

  Future<void> _fetchDeepSeekBalance(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _loadingBalance = true;
      _balanceError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.deepseek.com/user/balance'),
        headers: {
          'Authorization': 'Bearer $key',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isAvailable = data['is_available'] as bool? ?? false;
        final list = data['balance_infos'] as List<dynamic>?;
        String? total;
        String? granted;
        String? toppedUp;
        if (list != null && list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          total = first['total_balance']?.toString();
          granted = first['granted_balance']?.toString();
          toppedUp = first['topped_up_balance']?.toString();
        }

        if (mounted) {
          setState(() {
            _loadingBalance = false;
            _balanceAvailable = isAvailable;
            _totalBalance = total;
            _grantedBalance = granted;
            _toppedUpBalance = toppedUp;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingBalance = false;
            _balanceError = '查询失败 (HTTP ${response.statusCode})';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingBalance = false;
          _balanceError = '网络或密钥异常';
        });
      }
    }
  }

  Widget _buildBalanceBar() {
    if (_loadingBalance) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              '正在查询 DeepSeek 实时额度…',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_balanceError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFEF4444)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _balanceError!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
              ),
            ),
            InkWell(
              onTap: () => _fetchDeepSeekBalance(_apiKey.text.trim()),
              child: const Text(
                '重试',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
              ),
            ),
          ],
        ),
      );
    }

    // 尚未查询：展示轻量级「查询实时额度」操作条
    if (_totalBalance == null && _balanceAvailable == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '支持查询官方账户剩余额度',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          InkWell(
            onTap: () => _fetchDeepSeekBalance(_apiKey.text.trim()),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '查询实时额度',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 已查询成功：展示紧凑高级的额度条
    final isAvailable = _balanceAvailable == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAvailable ? const Color(0xFF00B42A) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            isAvailable ? '可用' : '耗尽',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAvailable ? const Color(0xFF00B42A) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '¥ $_totalBalance ',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                children: [
                  if (_toppedUpBalance != null || _grantedBalance != null)
                    TextSpan(
                      text: '(充值 ¥${_toppedUpBalance ?? "0"} · 赠送 ¥${_grantedBalance ?? "0"})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF64748B)),
                    ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => _fetchDeepSeekBalance(_apiKey.text.trim()),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  AiSettings _buildSettings() {
    final current = ref.read(aiSettingsProvider);
    final preset = presetById('deepseek');
    final model = current.model.trim().isNotEmpty
        ? current.model.trim()
        : (preset?.model ?? 'deepseek-reasoner');
    return AiSettings(
      enabled: true,
      protocol: preset?.protocol ?? AiProtocol.openai,
      baseUrl: preset?.baseUrl ?? 'https://api.deepseek.com',
      model: model,
      maxTokens: 8192,
      timeoutSeconds: 180,
      persona: 'socratic_master',
    );
  }

  Future<void> _save() async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入有效的 API Key')),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      await ref.read(secretStoreProvider).saveAiApiKey(key);
      try {
        await ref.read(configRepositoryProvider).saveAiSettings(_buildSettings());
      } catch (e) {
        debugPrint('Config save warning: $e');
      }

      ref
        ..invalidate(appConfigProvider)
        ..invalidate(aiApiKeyProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存')),
      );
      _fetchDeepSeekBalance(key);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
