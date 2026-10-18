import 'package:absolute_moment_app/data/credentials/credentials_store.dart';
import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/features/ai_settings/ai_settings_page.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecretStore extends SecretStore {
  String? saved;

  @override
  Future<void> saveAiApiKey(String apiKey) async => saved = apiKey;

  @override
  Future<String?> loadAiApiKey() async => saved;
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeSecretStore secrets,
  String initialKey = 'sk-test',
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final store = MemoryFileStore();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialStorageRootProvider.overrideWithValue(''),
        fileStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(secrets),
        aiApiKeyProvider.overrideWith((ref) async => initialKey),
      ],
      child: const MaterialApp(home: AiSettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('渲染推荐模型名称与 API Key 输入卡片', (tester) async {
    final secrets = _FakeSecretStore();
    await _pump(tester, secrets: secrets, initialKey: 'sk-existing-key');

    // 验证模型标签
    expect(find.text('deepseek-reasoner'), findsWidgets);
    // 验证标题与说明
    expect(find.text('设置'), findsOneWidget);
    // 验证存在保存按钮
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('输入新 Key 后点击保存正常触发写入', (tester) async {
    final secrets = _FakeSecretStore();
    await _pump(tester, secrets: secrets, initialKey: '');

    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);

    await tester.enterText(inputFinder, 'sk-new-valid-key');
    await tester.pumpAndSettle();

    final saveBtn = find.text('保存');
    await tester.tap(saveBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(secrets.saved, equals('sk-new-valid-key'));
  });
}
