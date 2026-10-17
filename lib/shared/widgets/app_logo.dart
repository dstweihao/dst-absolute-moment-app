import 'package:flutter/material.dart';

/// 「绝对时刻」logo —— 一条进度轨 + 停在「此刻」的圆点。
///
/// 单一来源：既用于应用内展示，也由 [test/tools/generate_icons_test.dart]
/// 光栅化生成各平台启动图标，避免另存 SVG/位图实体。
///
/// 刻意不用对话气泡 / 问号这类「AI 助手」意象：这是一个关于**进度**的
/// 工具，标记的就是你此刻站在整条路线的哪里。
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
    this.background = false,
    this.glyphScale = 1.0,
  });

  /// 画布边长。
  final double size;

  /// 是否铺满底色（用于不透明图标母版）。
  final bool background;

  /// 圆角方块占画布边长比例（图标母版需留安全边距）。
  final double glyphScale;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: AppLogoPainter(
        background: background,
        glyphScale: glyphScale,
      ),
    );
  }
}

class AppLogoPainter extends CustomPainter {
  AppLogoPainter({required this.background, required this.glyphScale});

  final bool background;
  final double glyphScale;

  /// 与主题同一个科技蓝 —— 全 APP 唯一的品牌色
  static const Color _teal = Color(0xFF165DFF);
  static const Color _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final tileSide = s * glyphScale;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: tileSide,
      height: tileSide,
    );

    final tile = Paint()..color = _teal;
    if (background) {
      canvas.drawRect(Offset.zero & size, tile);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(tileSide * 0.22)),
        tile,
      );
    }

    final center = rect.center;
    final mark = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = tileSide * 0.075
      ..strokeCap = StrokeCap.round;

    // 进度轨 —— 左右留白对称，整组标记在画布正中
    final dotR = tileSide * 0.13;
    final half = tileSide * 0.30;
    canvas.drawLine(
      Offset(center.dx - half, center.dy),
      Offset(center.dx + half, center.dy),
      mark,
    );

    // 「此刻」—— 轨道正中的圆点，就是时间线上的这一个点
    canvas.drawCircle(center, dotR, Paint()..color = _white);
  }

  @override
  bool shouldRepaint(AppLogoPainter oldDelegate) =>
      oldDelegate.background != background ||
      oldDelegate.glyphScale != glyphScale;
}
