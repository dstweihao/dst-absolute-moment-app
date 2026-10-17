import 'dart:async';

import 'package:absolute_moment_app/data/updates/update_client.dart';
import 'package:absolute_moment_app/domain/models/update_info.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:absolute_moment_app/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'update_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReleaseInfo? fakeRelease;
  late Object? fakeError;
  late UpdateInstallerFn installer;

  setUp(() {
    fakeRelease = sampleRelease();
    fakeError = null;
    installer = (release, {httpClient, onProgress}) async =>
        const InstallResult(InstallOutcome.launched);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((ref) async => '1.0.0'),
          updateClientProvider.overrideWithValue(
            FakeUpdateClient(release: fakeRelease, error: fakeError),
          ),
          updateInstallerProvider.overrideWithValue(installer),
          openReleasePageProvider.overrideWithValue(
            (url) async => const InstallResult(InstallOutcome.openedInBrowser),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: AppRouter.build(initialLocation: AppRouter.update),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 平台覆盖必须在用例体内复位 —— 框架在 body 返回后立刻校验
  /// 「foundation 调试变量有没有被改动」，tearDown 里清已经太晚。
  void updateTest(
    String name,
    Future<void> Function(WidgetTester) body, {
    TargetPlatform platform = TargetPlatform.windows,
  }) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  updateTest('未检查时只给一个检查按钮，点完亮出新版本与发布说明', (tester) async {
    await pump(tester);

    expect(find.text('尚未检查过更新。'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('下载并更新'), findsNothing);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.textContaining('新版本 v1.2.0'), findsOneWidget);
    expect(find.textContaining('修了几个一直没空管的边界情况'), findsOneWidget);
    expect(find.text('下载并更新'), findsOneWidget);
    expect(find.text('前往下载页'), findsOneWidget);
  });

  updateTest('已是最新时不出现任何更新按钮', (tester) async {
    fakeRelease = sampleRelease(tagName: 'v1.0.0');
    await pump(tester);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('已是最新版本'), findsOneWidget);
    expect(find.text('下载并更新'), findsNothing);
    expect(find.text('前往下载页'), findsNothing);
    expect(find.text('再查一次'), findsOneWidget);
  });

  updateTest('仓库还没有正式发布：也算最新，不当成错误', (tester) async {
    fakeRelease = null;
    await pump(tester);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.text('已是最新版本'), findsOneWidget);
    expect(find.textContaining('仓库暂无正式发布'), findsOneWidget);
  });

  updateTest('检查失败给出可读提示，按钮变重试', (tester) async {
    fakeError = const UpdateException('检查过于频繁，请稍后再试');
    await pump(tester);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    expect(find.textContaining('检查过于频繁'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  updateTest('下载中按钮禁用，完成后给出收尾提示', (tester) async {
    final completer = Completer<InstallResult>();
    installer = (release, {httpClient, onProgress}) => completer.future;

    await pump(tester);
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('下载并更新'));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '正在下载…'),
    );
    expect(button.onPressed, isNull, reason: '下载中不许重复触发');

    completer.complete(const InstallResult(InstallOutcome.launched));
    await tester.pumpAndSettle();

    expect(find.textContaining('已启动安装程序'), findsOneWidget);
  });

  updateTest(
    '非桌面端不提供应用内下载，只把人送到下载页',
    (tester) async {
      await pump(tester);

      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();

      expect(find.text('前往下载页'), findsOneWidget);
      expect(find.text('下载并更新'), findsNothing,
          reason: '移动端没有可落地的安装包，不该给出会失败的按钮');
    },
    platform: TargetPlatform.android,
  );
}
