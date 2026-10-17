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
  // 外观
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
            '配好之后，拆塔官会在七阶段里拷问你的答案。'
            '不配置也能走完闭环 —— 只是转为纯自评。',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          _kv('当前状态', ready ? '已配置 · ${settings.model}' : '未配置'),
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
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('关于与开发者', style: AppTypography.subtitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('绝对时刻 (Absolute Moment) · 现代 C++ 交互式推导工作台', style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          _kv('当前版本', 'v$version'),
          _interactiveKv(
            k: 'GitHub',
            v: 'https://github.com/dstweihao/dst-absolute-moment-app',
            onTap: () => _openUrl('https://github.com/dstweihao/dst-absolute-moment-app'),
          ),
          _interactiveKv(
            k: '个人网站',
            v: 'https://dstweihao.cn',
            onTap: () => _openUrl('https://dstweihao.cn'),
          ),
          _interactiveKv(
            k: '微信公众号',
            v: '码上生长 (点击复制)',
            actionIcon: Icons.copy_rounded,
            onTap: () => _copyText('码上生长', '已复制微信公众号：码上生长'),
          ),
          const SizedBox(height: AppSpacing.md),
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

  Widget _interactiveKv({
    required String k,
    required String v,
    required VoidCallback onTap,
    IconData? actionIcon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: Text(k, style: AppTypography.caption),
            ),
            Expanded(
              child: Text(
                v,
                style: AppTypography.body.copyWith(
                  fontSize: 14,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              actionIcon ?? Icons.open_in_new_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tip),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(k, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(
              v,
              style: AppTypography.body.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
