import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/domain/models/ai_settings.dart';
import 'package:absolute_moment_app/features/settings/storage_settings_page.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('系统设置页完整呈现 AI 配置入口与全部功能聚合', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialStorageRootProvider.overrideWithValue(''),
          fileStoreProvider.overrideWithValue(MemoryFileStore()),
          aiSettingsProvider.overrideWithValue(AiSettings.defaults),
          aiApiKeyProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: StorageSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('系统设置与功能'), findsOneWidget);
    expect(find.text('AI 配置'), findsOneWidget);
    expect(find.text('全部功能'), findsOneWidget);
    expect(find.text('38 关标准学习路线'), findsOneWidget);
  });
}
