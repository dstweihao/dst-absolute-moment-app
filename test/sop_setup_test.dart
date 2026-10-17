import 'package:absolute_moment_app/data/repositories/checkin_repository.dart';
import 'package:absolute_moment_app/data/repositories/resource_scanner.dart';
import 'package:absolute_moment_app/data/repositories/track_repository.dart';
import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/features/sop/sop_setup_page.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 阶段 0 —— 输入源清单来自文件夹，不是让用户凭空敲
///
/// 这组测试盯三件事：清单里出现的是文件夹里的真实文档；默认就是全选；
/// 文件夹是空的时候纯白板照样能开始（不设置不是失败）。
Future<void> _pump(WidgetTester tester, {required MemoryFileStore learning}) async {
  // ListView 是懒构建的：视口太矮时底部的「开始」按钮根本不会被建出来
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialStorageRootProvider.overrideWithValue(''),
        fileStoreProvider.overrideWithValue(MemoryFileStore()),
        initialLearningRootProvider.overrideWithValue('/res'),
        learningFileStoreProvider.overrideWithValue(learning),
        trackRepositoryProvider.overrideWithValue(
          TrackRepository(ResourceScanner(learning)),
        ),
        checkinRepositoryProvider.overrideWithValue(
          CheckinRepository(MemoryFileStore()),
        ),
      ],
      child: const MaterialApp(home: SopSetupPage()),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('文件夹里的文档成为输入源清单', (tester) async {
    final learning = MemoryFileStore();
    await learning.write('/res/业务背景.md', '电商订单系统，日单量 200 万。');
    await learning.write('/res/进度.txt', '看到第 12 章。');

    await _pump(tester, learning: learning);

    expect(find.text('阶段 0：输入源建档'), findsOneWidget);
    expect(find.text('业务背景'), findsOneWidget);
    expect(find.text('进度'), findsOneWidget);
    expect(find.textContaining('电商订单系统'), findsNothing,
        reason: '清单只给文件名，正文留给 AI 看，不占版面');
  });

  testWidgets('默认全选 —— 文件夹是他自己挑的，不该让他再勾一遍', (tester) async {
    final learning = MemoryFileStore();
    await learning.write('/res/业务背景.md', '正文 A');
    await learning.write('/res/进度.txt', '正文 B');
    await learning.write('/res/排错.md', '正文 C');

    await _pump(tester, learning: learning);

    expect(find.text('已选 3 / 3'), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsNWidgets(3));
    expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
  });

  testWidgets('手动取消一项后，只少了那一项', (tester) async {
    final learning = MemoryFileStore();
    await learning.write('/res/业务背景.md', '正文 A');
    await learning.write('/res/进度.txt', '正文 B');

    await _pump(tester, learning: learning);

    await tester.tap(find.text('进度'));
    await tester.pumpAndSettle();

    expect(find.text('已选 1 / 2'), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
  });

  testWidgets('文档多长都显示真实字数，不再有「已截断」', (tester) async {
    final learning = MemoryFileStore();
    const length = 12345;
    await learning.write('/res/长文.md', 'x' * length);

    await _pump(tester, learning: learning);

    expect(find.textContaining('$length 字'), findsOneWidget);
    expect(find.textContaining('已截断'), findsNothing);
  });

  testWidgets('没有「确认输入源」这道关卡 —— 按钮一开始就能点', (tester) async {
    final learning = MemoryFileStore();
    await learning.write('/res/业务背景.md', '正文');

    await _pump(tester, learning: learning);

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
      reason: '默认已经全选，再要一次确认就是纯障碍',
    );
    expect(find.textContaining('确认今天的输入源'), findsNothing);
  });

  testWidgets('文件夹为空时给出路，而不是拦住开始', (tester) async {
    await _pump(tester, learning: MemoryFileStore());

    expect(find.textContaining('还没有文档'), findsOneWidget);
    expect(find.textContaining('纯白板同样是一次有效的闭环'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });
}
