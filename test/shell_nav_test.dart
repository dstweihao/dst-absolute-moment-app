import 'package:absolute_moment_app/app.dart';
import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/features/learn/learn_page.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:absolute_moment_app/shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialStorageRootProvider.overrideWithValue(''),
          fileStoreProvider.overrideWithValue(MemoryFileStore()),
          aiApiKeyProvider.overrideWith((ref) async => null),
        ],
        child: const AbsoluteMomentApp(initialFirstRunDone: true),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('AppShell 渲染沉浸式主架构', (tester) async {
    await pumpApp(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(LearnPage), findsOneWidget);
  });
}
