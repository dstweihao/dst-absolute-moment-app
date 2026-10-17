import 'package:absolute_moment_app/data/repositories/checkin_repository.dart';
import 'package:absolute_moment_app/data/repositories/track_repository.dart';
import 'package:absolute_moment_app/data/seed/standard_curriculum.dart';
import 'package:absolute_moment_app/data/repositories/resource_scanner.dart';
import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/features/tracks/nodes_page.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 个性化资源是**补充**，不是替换：
/// 用户文件夹里的节点必须作为「补充关」出现在内置路线之后，
/// 既不能顶掉任何内置关卡，也不能插进主线中间。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const extraYaml = '''
id: "x-side"
title: "我自己加的一关"
phase: 1
phase_name: "自有阶段"
progress_range: [0, 10]
order: 99
socratic_questions:
  - id: Q0
    level: "基础"
    text: "这一块你怎么讲清楚？"
acceptance_criteria:
  - "能不看笔记复述"
''';

  Future<void> pumpNodes(WidgetTester tester, {required bool withExtra}) async {
    final learningStore = MemoryFileStore();
    if (withExtra) {
      await learningStore.write('/my/nodes/x-side.yaml', extraYaml);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialStorageRootProvider.overrideWithValue(''),
          fileStoreProvider.overrideWithValue(MemoryFileStore()),
          // 仓库直接注入，绕开真实文件系统
          trackRepositoryProvider
              .overrideWithValue(TrackRepository(ResourceScanner(learningStore))),
          checkinRepositoryProvider.overrideWithValue(
            CheckinRepository(MemoryFileStore()),
          ),
        ],
        child: const MaterialApp(
          home: NodesPage(trackId: StandardCurriculum.cppTrackId),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('没有补充资源时不出现「个性化补充」区块', (tester) async {
    await pumpNodes(tester, withExtra: false);

    expect(find.text('个性化补充'), findsNothing);

    // 首尾两端的分组标题都要有 —— 中文序数映射必须覆盖到「五」
    expect(find.textContaining('阶段一'), findsOneWidget);
    await tester.dragUntilVisible(
      find.textContaining('阶段五'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    expect(find.textContaining('阶段五'), findsOneWidget,
        reason: '第五阶段的分组标题应写成「阶段五」，不是「阶段5」');
  });

  testWidgets('有补充资源时，追加「个性化补充」区块且不替换内置主线', (tester) async {
    await pumpNodes(tester, withExtra: true);

    // 内置主线必须还在 —— 这是「补充」而非「替换」的核心断言
    expect(find.textContaining('阶段一'), findsOneWidget);
    expect(find.text('第一个程序'), findsOneWidget,
        reason: '内置第一关不该被个人内容顶掉');

    // 补充区在五个阶段之后，要滚动才会被构建
    await tester.dragUntilVisible(
      find.text('个性化补充'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    expect(find.text('个性化补充'), findsOneWidget,
        reason: '个人节点应独立成区，列在五阶段之后');
    expect(find.text('我自己加的一关'), findsOneWidget);
  });

  testWidgets('补充关不计入主线进度分母', (tester) async {
    await pumpNodes(tester, withExtra: true);

    // 主线仍是 37 关，分子 0 —— 进度条写的是 0%，分母里不含补充关
    expect(find.text('已通过 0 / 37 关'), findsOneWidget);
    expect(find.textContaining('另有 1 个补充关'), findsOneWidget);
  });
}
