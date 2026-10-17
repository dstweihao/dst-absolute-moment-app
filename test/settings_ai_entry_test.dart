import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/domain/models/ai_settings.dart';
import 'package:absolute_moment_app/features/settings/storage_settings_page.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 配置入口必须**一直在设置页里**。
///
/// 曾经的坑：入口只存在于「未配置」横幅与统计页一个没文字的图标上，
/// 配好一次之后就再也找不到 —— 想改模型得先想起来那个机器人图标。
/// 这组测试盯的就是「配好之后入口依然在」。
Future<void> _pump(
  WidgetTester tester, {
  required AiSettings settings,
  required String? apiKey,
}) async {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialStorageRootProvider.overrideWithValue(''),
        initialLearningRootProvider.overrideWithValue(''),
        fileStoreProvider.overrideWithValue(MemoryFileStore()),
        aiSettingsProvider.overrideWithValue(settings),
        aiApiKeyProvider.overrideWith((ref) async => apiKey),
      ],
      child: const MaterialApp(home: StorageSettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('未配置时给出「去配置 AI」', (tester) async {
    await _pump(tester, settings: AiSettings.defaults, apiKey: null);

    expect(find.text('AI 配置'), findsOneWidget);
    expect(find.text('未配置'), findsOneWidget);
    expect(find.text('去配置 AI'), findsOneWidget);
  });

  testWidgets('配好之后入口仍在，且显示当前模型', (tester) async {
    await _pump(
      tester,
      settings: const AiSettings(enabled: true, model: 'deepseek-v4-pro'),
      apiKey: 'sk-test',
    );

    expect(find.textContaining('已配置'), findsOneWidget);
    expect(find.textContaining('deepseek-v4-pro'), findsOneWidget);
    expect(find.text('修改 AI 配置'), findsOneWidget,
        reason: '配好之后改模型不能没有入口');
  });

  testWidgets('填了模型但没填 Key，仍算未配置', (tester) async {
    await _pump(
      tester,
      settings: const AiSettings(enabled: true, model: 'deepseek-v4-pro'),
      apiKey: '',
    );

    expect(find.text('未配置'), findsOneWidget);
    expect(find.text('去配置 AI'), findsOneWidget);
  });
}
