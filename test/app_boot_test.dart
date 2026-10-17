import 'package:absolute_moment_app/app.dart';
import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/features/learn/learn_page.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'update_fakes.dart';

void main() {
  testWidgets('启动后直接进入学习界面，无引导门槛', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 存储根目录正常由 main() 注入；测试里直接给内存实现
          initialStorageRootProvider.overrideWithValue(''),
          fileStoreProvider.overrideWithValue(MemoryFileStore()),
          // 避免在 fake-async 环境里触发 flutter_secure_storage 插件通道
          aiApiKeyProvider.overrideWith((ref) async => null),
          // 启动时的静默版本检查不该真的联网
          updateClientProvider.overrideWithValue(FakeUpdateClient()),
        ],
        child: const AbsoluteMomentApp(),
      ),
    );

    // 路由落地是异步的，用有界轮询推进帧
    var booted = false;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tester.any(find.byType(LearnPage))) {
        booted = true;
        break;
      }
    }

    expect(booted, true, reason: '启动后应落在学习界面');
    expect(find.byType(LearnPage), findsOneWidget);
  });

  testWidgets('AI 未配置时给出提示但不阻断进入', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialStorageRootProvider.overrideWithValue(''),
          fileStoreProvider.overrideWithValue(MemoryFileStore()),
          aiApiKeyProvider.overrideWith((ref) async => null),
          updateClientProvider.overrideWithValue(FakeUpdateClient()),
        ],
        child: const AbsoluteMomentApp(),
      ),
    );

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (tester.any(find.text('去配置'))) break;
    }

    expect(find.text('去配置'), findsOneWidget);
  });
}
