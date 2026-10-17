import 'package:absolute_moment_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 冒烟测试：验证主题能正常构建。
  // 真正的业务逻辑测试见 test/ 下的其他文件。
  testWidgets('深色主题能正常构建', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: Text('绝对时刻')),
      ),
    );

    expect(find.text('绝对时刻'), findsOneWidget);
  });
}
