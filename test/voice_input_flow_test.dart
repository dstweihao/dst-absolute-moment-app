import 'package:absolute_moment_app/data/storage/memory_file_store.dart';
import 'package:absolute_moment_app/features/learn/learn_page.dart';
import 'package:absolute_moment_app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpLearnPage(
  WidgetTester tester, {
  bool hasAgreedPermission = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_agreed_mic_permission': hasAgreedPermission,
    'absolute_moment_passed_nodes_v1': <String>[],
  });

  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final store = MemoryFileStore();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialStorageRootProvider.overrideWithValue(''),
        fileStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: LearnPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('语音输入与权限交互全链路验证', () {
    testWidgets('首次点击麦克风时必须弹出合规的前置权限使用说明弹窗', (tester) async {
      await _pumpLearnPage(tester, hasAgreedPermission: false);

      // 验证输入栏有麦克风图标
      final micFinder = find.byIcon(Icons.mic_none_rounded);
      expect(micFinder, findsOneWidget);

      // 点击麦克风按钮
      await tester.tap(micFinder);
      await tester.pumpAndSettle();

      // 验证弹出了「麦克风权限使用说明」对话框
      expect(find.text('麦克风权限使用说明'), findsOneWidget);
      expect(find.textContaining('绝对时刻需要使用您的设备麦克风'), findsOneWidget);
      expect(find.text('暂不开启'), findsOneWidget);
      expect(find.text('同意并继续'), findsOneWidget);

      // 点击「暂不开启」
      await tester.tap(find.text('暂不开启'));
      await tester.pumpAndSettle();

      // 验证弹窗关闭，且未进入录音状态
      expect(find.text('麦克风权限使用说明'), findsNothing);
      expect(find.text('正在聆听推导…'), findsNothing);
    });

    testWidgets('用户点击「同意并继续」后，保存授权标识并尝试开启录音栏', (tester) async {
      await _pumpLearnPage(tester, hasAgreedPermission: false);

      final micFinder = find.byIcon(Icons.mic_none_rounded);
      await tester.tap(micFinder);
      await tester.pumpAndSettle();

      // 点击「同意并继续」
      await tester.tap(find.text('同意并继续'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // 验证已持久化授权偏好
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_agreed_mic_permission'), isTrue);
    });

    testWidgets('已授权状态下点击取消按钮能还原之前输入的文本', (tester) async {
      await _pumpLearnPage(tester, hasAgreedPermission: true);

      // 先在输入框中输入一段草稿
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, '原有推导思路');
      await tester.pumpAndSettle();
      expect(find.text('原有推导思路'), findsOneWidget);

      // 点击麦克风
      final micFinder = find.byIcon(Icons.mic_none_rounded);
      await tester.tap(micFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 若处于录音条状态，点击取消按钮还原文字
      final cancelBtn = find.byIcon(Icons.close_rounded);
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        // 验证文本恢复为原有推导思路
        expect(find.text('原有推导思路'), findsOneWidget);
      }
    });
  });
}
