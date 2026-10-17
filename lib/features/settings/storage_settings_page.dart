import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/updates/update_config.dart';
import '../../providers.dart';
import '../../router.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_logo.dart';

/// 系统设置页
class StorageSettingsPage extends ConsumerStatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  ConsumerState<StorageSettingsPage> createState() =>
      _StorageSettingsPageState();
}

class _StorageSettingsPageState extends ConsumerState<StorageSettingsPage> {
  late final TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _pathController =
        TextEditingController(text: ref.read(storageRootProvider));
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('系统设置与功能')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
        children: [
          // 核心：AI 终端与 DeepSeek 配置（填 Key、模型）
          _aiSection(),
          const SizedBox(height: AppSpacing.cardGap),
          
          // 其他功能入口（原底部/侧边能力聚合）
          _featureNavigationSection(),
          const SizedBox(height: AppSpacing.cardGap),

          // 关于与作者（GitHub、微信公众号、个人网站、版本更新）
          _aboutSection(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 功能聚合中心（路线、看板、统计）
  // ------------------------------------------------------------------

  Widget _featureNavigationSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.apps_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('全部功能', style: AppTypography.subtitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('主界面保持沉浸对话，其余功能统一在此调用。', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_tree_rounded, color: Color(0xFF2E6FF2), size: 20),
              ),
              title: const Text('38 关标准学习路线'),
              subtitle: const Text('查看关卡拓扑、各关重点与阶段进阶'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRouter.tracks),
            ),
          ),
          const Divider(height: 1),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dashboard_rounded, color: Color(0xFF10B981), size: 20),
              ),
              title: const Text('学习看板'),
              subtitle: const Text('今日攻坚状态与连击打卡记录'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRouter.dashboard),
            ),
          ),
          const Divider(height: 1),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insights_rounded, color: Color(0xFF8B5CF6), size: 20),
              ),
              title: const Text('数据统计与分析'),
              subtitle: const Text('能力维度雷达、学习历史与自评得分'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(AppRouter.stats),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 外观与配置
  // ------------------------------------------------------------------

  Widget _aiSection() {
    final settings = ref.watch(aiSettingsProvider);
    final ready = ref.watch(aiAvailableProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('AI 配置', style: AppTypography.subtitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '配好之后，AI 导师会带你逐关推导。'
            '不配置也能走完闭环 —— 只是转为纯自评模式。',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          _kv('当前状态', ready ? '已配置 · ${settings.model}' : '未配置'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRouter.aiSettings),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(ready ? '修改 AI 配置' : '去配置 AI'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutSection() {
    final version =
        ref.watch(appVersionProvider).value ?? UpdateConfig.fallbackVersion;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
                ),
                alignment: Alignment.center,
                child: const AppLogo(size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '绝对时刻',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '版本 v$version',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          _interactiveItem(
            icon: Icons.sports_esports_rounded,
            label: '核心功能',
            value: '像打怪闯关一样学现代 C++（38 个精选关卡）',
            isClickable: false,
          ),
          const SizedBox(height: 12),
          _interactiveItem(
            icon: Icons.lightbulb_outline_rounded,
            label: '解决痛点',
            value: '告别死记八股与 AI 喂饭，带你真正搞懂底层机制',
            isClickable: false,
          ),
          const SizedBox(height: 12),
          _interactiveItem(
            icon: Icons.link_rounded,
            label: 'GitHub',
            value: 'github.com/dstweihao',
            copyContent: 'https://github.com/dstweihao',
            onTap: () => _openUrl('https://github.com/dstweihao'),
          ),
          const SizedBox(height: 12),
          _interactiveItem(
            icon: Icons.language_rounded,
            label: '个人网站',
            value: 'https://dstweihao.cn',
            copyContent: 'https://dstweihao.cn',
            onTap: () => _openUrl('https://dstweihao.cn'),
          ),
          const SizedBox(height: 12),
          _interactiveItem(
            icon: Icons.campaign_rounded,
            label: '微信公众号',
            value: '码上生长 (点击或长按复制)',
            copyContent: '码上生长',
            actionIcon: Icons.copy_rounded,
            onTap: () => _copyText('码上生长', '已复制微信公众号：码上生长'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRouter.update),
              icon: const Icon(Icons.system_update_alt_rounded, size: 18),
              label: const Text('检查版本更新'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _interactiveItem({
    required IconData icon,
    required String label,
    required String value,
    String? copyContent,
    VoidCallback? onTap,
    IconData actionIcon = Icons.open_in_new_rounded,
    bool isClickable = true,
  }) {
    final toCopy = copyContent ?? value;
    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isClickable ? AppColors.primary : const Color(0xFF1E293B),
                decoration: isClickable ? TextDecoration.underline : TextDecoration.none,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isClickable) ...[
            const SizedBox(width: 4),
            Icon(actionIcon, size: 14, color: AppColors.primary),
          ],
        ],
      ),
    );

    return InkWell(
      onTap: onTap ?? (isClickable ? () => _copyText(toCopy, '已复制 $label：$toCopy') : null),
      onLongPress: () => _copyText(toCopy, '已复制 $label：$toCopy'),
      borderRadius: BorderRadius.circular(8),
      child: rowContent,
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(k, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(v, style: AppTypography.body),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyText(String text, String tip) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDCFCE7),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 24,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '已复制',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tip,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('知道了', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
