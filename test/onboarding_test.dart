import 'package:absolute_moment_app/app.dart';
import 'package:absolute_moment_app/data/settings/app_settings_store.dart';
import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/features/onboarding/onboarding_page.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('首次使用标记', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('未设置时为 false，写入后为 true', () async {
      final store = AppSettingsStore();
      expect(await store.isFirstRunDone(), false);

      await store.setFirstRunDone();
      expect(await store.isFirstRunDone(), true);
    });
  });

  group('启动落点', () {
    Future<void> pumpApp(WidgetTester tester, {required bool firstRunDone}) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialStorageRootProvider.overrideWithValue(''),
            fileStoreProvider.overrideWithValue(MemoryFileStore()),
            aiApiKeyProvider.overrideWith((ref) async => null),
          ],
          child: AbsoluteMomentApp(initialFirstRunDone: firstRunDone),
        ),
      );
    }

    Future<bool> settlesOn(WidgetTester tester, Finder finder) async {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (tester.any(finder)) return true;
      }
      return false;
    }

    testWidgets('首次启动落在引导页，直接是可选的个性化资源一步', (tester) async {
      await pumpApp(tester, firstRunDone: false);

      expect(await settlesOn(tester, find.byType(OnboardingPage)), true,
          reason: '首次启动应落在引导页');
      expect(find.text('欢迎使用绝对时刻'), findsWidgets);
      expect(find.text('个性化资源（可选补充）'), findsOneWidget,
          reason: '学习路径只有一个选项，不该做成假选择摆在第一步');
      expect(find.text('跳过'), findsOneWidget, reason: '引导全程可跳过');
    });

    testWidgets('非首次启动直接进学习界面，不出现引导', (tester) async {
      await pumpApp(tester, firstRunDone: true);

      // 等界面稳定后再断言引导页从未出现
      await settlesOn(tester, find.text('拆塔官'));
      expect(find.byType(OnboardingPage), findsNothing,
          reason: '已完成引导时不应再出现引导页');
    });

    testWidgets('走完两步后标记引导完成并进入学习界面', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpApp(tester, firstRunDone: false);
      await settlesOn(tester, find.byType(OnboardingPage));

      // ① 个性化资源
      expect(find.textContaining('自动递归扫描'), findsOneWidget,
          reason: '应说明目录结构不限、自动扫描');
      expect(find.textContaining('是补充，不是替换'), findsOneWidget,
          reason: '必须说清语义是补充而非替换内置路线');
      expect(find.text('跳过，用内置标准路线'), findsOneWidget,
          reason: '必须允许不补充关卡直接跳过');

      // ① 不补充关卡，直接下一步 → ② 完成
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('开始学习'), findsOneWidget);
      expect(find.textContaining('仅内置标准路线'), findsOneWidget,
          reason: '未选文件夹时应显示只有内置标准路线');

      // ② 开始学习
      await tester.tap(find.text('开始学习'));
      await settlesOn(tester, find.text('拆塔官'));

      expect(find.byType(OnboardingPage), findsNothing,
          reason: '完成后应离开引导页');
      expect(await AppSettingsStore().isFirstRunDone(), true,
          reason: '完成后应写入首次使用标记');
    });
  });
}
