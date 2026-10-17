import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../data/ai/provider_presets.dart';
import '../../data/updates/update_config.dart';
import '../../domain/enums/app_enums.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/node.dart';
import '../../domain/models/update_info.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_logo.dart';
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
  bool _checkingUpdate = false;

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
    final appVersion = ref.watch(appVersionProvider).value ?? UpdateConfig.fallbackVersion;
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          '保存',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsCard(totalNodes),
                const SizedBox(height: 10),
                _buildKeyCard(modelName),
                const SizedBox(height: 10),
                _buildProjectCard(appVersion),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(int totalNodes) {
    final progressPercent = totalNodes > 0 ? (_passedCount / totalNodes * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insert_chart_outlined_rounded, size: 15, color: Color(0xFF8E8E93)),
              const SizedBox(width: 6),
              const Text(
                'C++ 38 关进阶路线',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
              ),
              const Spacer(),
              Text(
                '已掌握 $_passedCount / $totalNodes · $progressPercent%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2.5),
            child: LinearProgressIndicator(
              value: totalNodes > 0 ? (_passedCount / totalNodes).clamp(0.0, 1.0) : 0.0,
              minHeight: 5,
              backgroundColor: const Color(0xFFF2F2F7),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  '已掌握',
                  '$_passedCount 关',
                  const Color(0xFF34C759),
                ),
              ),
              Container(width: 0.5, height: 20, color: const Color(0xFFE5E5EA)),
              Expanded(
                child: _buildMetricItem(
                  '待突破',
                  '${(totalNodes - _passedCount).clamp(0, totalNodes)} 关',
                  const Color(0xFF8E8E93),
                ),
              ),
              Container(width: 0.5, height: 20, color: const Color(0xFFE5E5EA)),
              Expanded(
                child: _buildMetricItem(
                  '通关率',
                  '$progressPercent%',
                  AppColors.primary,
                ),
              ),
              Container(width: 0.5, height: 20, color: const Color(0xFFE5E5EA)),
              Expanded(
                child: _buildMetricItem(
                  '攻坚期',
                  '${(totalNodes - _passedCount).clamp(0, totalNodes)} 天',
                  const Color(0xFF1C1C1E),
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
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF8E8E93)),
        ),
      ],
    );
  }

  Widget _buildKeyCard(String modelName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.key_rounded, size: 15, color: Color(0xFF8E8E93)),
              const SizedBox(width: 6),
              const Text(
                'DeepSeek API Key',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  modelName.isNotEmpty ? modelName : 'deepseek-reasoner',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _apiKey,
            obscureText: _obscureKey,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'sk-xxxxxxxxxxxxxxxxxxxxxxxx',
              hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF2F2F7),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary, width: 1.2),
              ),
              suffixIcon: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 17,
                  color: const Color(0xFF8E8E93),
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            ),
            SizedBox(width: 8),
            Text(
              '正在查询 DeepSeek 实时额度…',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF8E8E93)),
            ),
          ],
        ),
      );
    }

    if (_balanceError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2F2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFFF3B30)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _balanceError!,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFFFF3B30)),
              ),
            ),
            InkWell(
              onTap: () => _fetchDeepSeekBalance(_apiKey.text.trim()),
              child: const Text(
                '重试',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFFF3B30)),
              ),
            ),
          ],
        ),
      );
    }

    if (_totalBalance == null && _balanceAvailable == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '支持查询官方账户剩余额度',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF8E8E93)),
          ),
          InkWell(
            onTap: () => _fetchDeepSeekBalance(_apiKey.text.trim()),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '查询实时额度',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final isAvailable = _balanceAvailable == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAvailable ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isAvailable ? '可用' : '耗尽',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isAvailable ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '¥ $_totalBalance ',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                children: [
                  if (_toppedUpBalance != null || _grantedBalance != null)
                    TextSpan(
                      text: '(充值 ¥${_toppedUpBalance ?? "0"} · 赠送 ¥${_grantedBalance ?? "0"})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Color(0xFF8E8E93)),
                    ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => _fetchDeepSeekBalance(_apiKey.text.trim()),
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF8E8E93)),
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
      _showCenteredDialog(
        title: '提示',
        message: '请先输入有效的 API Key',
        isError: true,
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
      _showCenteredDialog(
        title: '保存成功',
        message: 'API Key 与模型配置已生效',
      );
      _fetchDeepSeekBalance(key);
    } catch (e) {
      if (!mounted) return;
      _showCenteredDialog(
        title: '保存失败',
        message: '保存出错：$e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showCenteredDialog({
    required String title,
    required String message,
    bool isError = false,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: 270,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x1F000000), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF3C3C43),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: isError ? const Color(0xFFFF3B30) : AppColors.primary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                    ),
                  ),
                  child: const Text(
                    '好',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(String version) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppLogo(size: 34),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '绝对时刻',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '版本 $version',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 26,
                child: OutlinedButton(
                  onPressed: _checkingUpdate ? null : _handleCheckUpdate,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side: const BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
                    backgroundColor: const Color(0xFFF2F2F7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: _checkingUpdate
                      ? const SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : Text(
                          '检查更新',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
          _buildAppleRow('项目简介', '像闯关打怪一样学现代 C++ · 不喂饭的 AI 导师'),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFF2F2F7)),
          _buildAppleRow('GitHub', 'github.com/dstweihao/dst-absolute-moment-app'),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFF2F2F7)),
          _buildAppleRow('个人网站', 'https://dstweihao.cn'),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFF2F2F7)),
          _buildAppleRow('微信公众号', '码上生长'),
        ],
      ),
    );
  }

  Widget _buildAppleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1C1C1E),
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    try {
      final current = await ref.read(appVersionProvider.future);
      final latest = await ref.read(updateClientProvider).checkLatest();

      if (!mounted) return;
      setState(() => _checkingUpdate = false);

      if (latest == null || !isNewerVersion(latest.tagName, current)) {
        _showCenteredDialog(
          title: '检查更新',
          message: '当前已是最新版本 (v$current)',
        );
        return;
      }

      _showUpdateDialog(current, latest);
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingUpdate = false);
      _showCenteredDialog(
        title: '检查更新失败',
        message: '网络或服务异常：$e',
        isError: true,
      );
    }
  }

  void _showUpdateDialog(String current, ReleaseInfo release) {
    bool downloading = false;
    double? downloadProgress;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Icon(Icons.system_update_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('发现新版本 ${release.tagName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前版本 v$current，最新发布 ${release.tagName}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                if (release.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        release.notes.trim(),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                ],
                if (downloading) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: downloadProgress,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    downloadProgress != null
                        ? '正在下载 ${(downloadProgress! * 100).toStringAsFixed(0)}%…'
                        : '正在连接下载源…',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                  ),
                ],
              ],
            ),
            actions: [
              if (!downloading)
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('暂不更新', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ),
              ElevatedButton(
                onPressed: downloading
                    ? null
                    : () async {
                        setDialogState(() {
                          downloading = true;
                          errorMsg = null;
                        });
                        try {
                          final installer = ref.read(updateInstallerProvider);
                          final result = await installer(
                            release,
                            onProgress: (p) {
                              setDialogState(() => downloadProgress = p);
                            },
                          );
                          if (!result.isSuccess) {
                            setDialogState(() {
                              downloading = false;
                              errorMsg = result.message;
                            });
                          } else {
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          }
                        } catch (e) {
                          setDialogState(() {
                            downloading = false;
                            errorMsg = '下载安装失败：$e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text(downloading ? '下载中…' : '立即下载更新', style: const TextStyle(fontSize: 13)),
              ),
            ],
          );
        },
      ),
    );
  }
}
