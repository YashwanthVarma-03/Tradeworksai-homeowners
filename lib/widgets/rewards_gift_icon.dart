import 'package:flutter/material.dart';

/// The thin, rounded outline gift used in the supplied F01 reference.
class RewardsGiftIcon extends StatelessWidget {
  const RewardsGiftIcon({super.key, required this.color, this.size = 18});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Center(
        child:
            CustomPaint(size: Size.square(size), painter: _GiftPainter(color)),
      );
}

class _GiftPainter extends CustomPainter {
  _GiftPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 8, 18, 4), const Radius.circular(1)),
        paint);
    canvas.drawPath(
        Path()
          ..moveTo(5, 12)
          ..lineTo(5, 20)
          ..quadraticBezierTo(5, 21, 6, 21)
          ..lineTo(18, 21)
          ..quadraticBezierTo(19, 21, 19, 20)
          ..lineTo(19, 12),
        paint);
    canvas.drawLine(const Offset(12, 8), const Offset(12, 21), paint);
    canvas.drawPath(
        Path()
          ..moveTo(12, 8)
          ..cubicTo(9, 8, 6, 8, 6, 5.5)
          ..cubicTo(6, 2, 11, 2, 12, 8)
          ..cubicTo(13, 2, 18, 2, 18, 5.5)
          ..cubicTo(18, 8, 15, 8, 12, 8),
        paint);
  }

  @override
  bool shouldRepaint(_GiftPainter oldDelegate) => color != oldDelegate.color;
}
