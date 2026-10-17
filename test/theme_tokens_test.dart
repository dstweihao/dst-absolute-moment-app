import 'package:absolute_moment_app/core/theme/app_colors.dart';
import 'package:absolute_moment_app/core/theme/app_spacing.dart';
import 'package:absolute_moment_app/core/theme/app_typography.dart';
import 'package:flutter_test/flutter_test.dart';

/// 设计 token 的护栏。
///
/// 颜色/圆角这种「看着不对但不会报错」的东西，靠肉眼过屏很容易漏。
/// 这里把几条硬规则钉死，改坏了立刻红。
void main() {
  group('调色板', () {
    test('暗色的 border 必须比 surfaceVariant 浅 —— 否则描边整个隐没', () {
      expect(AppPalette.dark.border, isNot(AppPalette.dark.surfaceVariant),
          reason: '两者同值时，「surfaceVariant 底 + 描边」的组件在暗色下没有边框');

      final borderLum = AppPalette.dark.border.computeLuminance();
      final variantLum = AppPalette.dark.surfaceVariant.computeLuminance();
      expect(borderLum, greaterThan(variantLum));
    });

    test('亮暗两套 token 名字对齐 —— 不会出现一边有一边没有', () {
      // 两条主题的字段一一对应由 AppPalette 的 const 构造保证；
      // 这里只兜住最容易漏的一处：背景/表面/描边的层次关系
      for (final p in [AppPalette.light, AppPalette.dark]) {
        expect(p.surface, isNot(p.background));
        expect(p.border, isNot(p.surface));
      }
    });

    test('阶段色 7 档都有，越界取色不抛异常', () {
      for (var i = 0; i < 7; i++) {
        expect(AppPalette.light.colorForStage(i), isNotNull);
        expect(AppPalette.dark.colorForStage(i), isNotNull);
      }
      // 越界钳到边界，不该崩
      expect(AppPalette.light.colorForStage(-1),
          AppPalette.light.colorForStage(0));
      expect(AppPalette.light.colorForStage(99),
          AppPalette.light.colorForStage(6));
    });
  });

  group('圆角与间距', () {
    test('圆角是同一套层级，不出现越级的怪值', () {
      // 从小到大：small < badge < input = button < tile < card < bottomSheet
      expect(AppRadius.small, lessThan(AppRadius.badge));
      expect(AppRadius.badge, lessThan(AppRadius.button));
      expect(AppRadius.input, AppRadius.button);
      expect(AppRadius.button, lessThan(AppRadius.tile));
      expect(AppRadius.tile, lessThan(AppRadius.card));
      expect(AppRadius.card, lessThan(AppRadius.bottomSheet));
      expect(AppRadius.bottomSheet, lessThan(AppRadius.circle));
    });

    test('间距都在 4pt 栅格上', () {
      const steps = [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.pageHorizontal,
        AppSpacing.cardPadding,
        AppSpacing.cardGap,
        AppSpacing.listGap,
        AppSpacing.bottomNavClearance,
      ];
      for (final s in steps) {
        expect(s % AppSpacing.xs, 0, reason: '$s 不在 4pt 栅格上');
      }
    });
  });

  group('排版', () {
    test('字号从大到小递进，且数据类样式是等宽的', () {
      expect(AppTypography.display.fontSize, greaterThan(AppTypography.title.fontSize!));
      expect(AppTypography.title.fontSize, greaterThan(AppTypography.subtitle.fontSize!));
      expect(AppTypography.subtitle.fontSize, greaterThan(AppTypography.body.fontSize!));
      expect(AppTypography.body.fontSize, greaterThan(AppTypography.caption.fontSize!));
      expect(AppTypography.caption.fontSize, greaterThan(AppTypography.label.fontSize!));

      expect(AppTypography.mono.fontFamily, isNotNull, reason: '数字要等宽才对得齐');
      expect(AppTypography.monoSmall.fontFamily, isNotNull);
    });
  });
}
