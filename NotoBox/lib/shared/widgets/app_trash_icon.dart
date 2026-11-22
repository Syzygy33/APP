import 'package:material_ui/material_ui.dart';

/// 全 App 统一的删除图标：实心圆角垃圾桶，桶身三条竖线镂空。
///
/// 为什么不用现成字体图标：Material 的 `delete_rounded` 只有**两条**竖线，
/// Lucide 的 `trash2` 是描边风格。要同时满足「实心 + 圆角 + 三条竖线」，
/// 只能按形状自己画。
///
/// 设计基准 24×24，按传入的 [size] 等比缩放。
class AppTrashIcon extends StatelessWidget {
  const AppTrashIcon({super.key, this.size = 20, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TrashPainter(color)),
    );
  }
}

class _TrashPainter extends CustomPainter {
  _TrashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 以 24 为基准换算比例，保证任意尺寸下比例一致
    final double s = size.width / 24;
    final Paint paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // 把手：盖子上方的小圆角块
    final RRect handle = RRect.fromLTRBR(
      9.6 * s,
      3.0 * s,
      14.4 * s,
      5.4 * s,
      Radius.circular(1.0 * s),
    );

    // 盖子：横向圆角条
    final RRect lid = RRect.fromLTRBR(
      3.2 * s,
      5.4 * s,
      20.8 * s,
      7.1 * s,
      Radius.circular(0.85 * s),
    );

    // 桶身：上宽下窄，底角圆润
    final Path body = Path()
      ..moveTo(4.9 * s, 7.9 * s)
      ..lineTo(19.1 * s, 7.9 * s)
      ..lineTo(18.2 * s, 19.4 * s)
      ..quadraticBezierTo(18.1 * s, 20.8 * s, 16.7 * s, 20.8 * s)
      ..lineTo(7.3 * s, 20.8 * s)
      ..quadraticBezierTo(5.9 * s, 20.8 * s, 5.8 * s, 19.4 * s)
      ..close();

    // 三条竖线：用路径相减挖空，露出背景色
    final Path slots = Path();
    for (final double cx in <double>[8.4, 12.0, 15.6]) {
      slots.addRRect(
        RRect.fromLTRBR(
          (cx - 0.62) * s,
          10.4 * s,
          (cx + 0.62) * s,
          17.8 * s,
          Radius.circular(0.62 * s),
        ),
      );
    }

    final Path bodyWithSlots = Path.combine(
      PathOperation.difference,
      body,
      slots,
    );

    canvas
      ..drawRRect(handle, paint)
      ..drawRRect(lid, paint)
      ..drawPath(bodyWithSlots, paint);
  }

  @override
  bool shouldRepaint(covariant _TrashPainter oldDelegate) =>
      oldDelegate.color != color;
}
