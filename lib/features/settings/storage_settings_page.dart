import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF165DFF).withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const AppLogo(size: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '绝对时刻',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(width: 6),
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
          _buildAppleRow('核心功能', '像打怪闯关一样学现代 C++（38 个精选关卡）'),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFF2F2F7)),
          _buildAppleRow('解决痛点', '告别死记八股与 AI 喂饭，带你真正搞懂内存与底层原理'),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFF2F2F7)),
          _buildAppleRow('GitHub', 'github.com/dstweihao/dst-absolute-moment-app'),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFF2F2F7)),
          _buildAppleRow('个人网站', 'https://dstweihao.cn'),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFF2F2F7)),
          _buildAppleRow('微信公众号', '码上生长'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRouter.update),
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('检查版本更新'),
            ),
          ),
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
