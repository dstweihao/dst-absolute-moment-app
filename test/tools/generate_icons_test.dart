// 图标母版生成器（非业务测试）。
//
// 用 Flutter 引擎把 AppLogoPainter 光栅化出两张母版，供 flutter_launcher_icons
// 再生成各平台启动图标。运行：
//   flutter test test/tools/generate_icons_test.dart
//
// 产物：
//   assets/icon/icon.png            不透明母版（iOS/Windows/macOS/web）
//   assets/icon/icon_foreground.png 透明前景（Android 自适应图标安全区）
import 'dart:io';
import 'dart:ui' as ui;

import 'package:absolute_moment_app/shared/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('生成图标母版', () async {
    await _render(
      background: true,
      glyphScale: 0.72,
      out: 'assets/icon/icon.png',
    );
    await _render(
      background: false,
      glyphScale: 0.58,
      out: 'assets/icon/icon_foreground.png',
    );
  });
}

Future<void> _render({
  required bool background,
  required double glyphScale,
  required String out,
}) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  AppLogoPainter(background: background, glyphScale: glyphScale)
      .paint(canvas, const Size(size, size));
  final picture = recorder.endRecording();

  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  Directory('assets/icon').createSync(recursive: true);
  File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
  expect(File(out).existsSync(), isTrue, reason: '应生成 $out');
}
