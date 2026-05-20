import 'dart:math' as math;

import 'package:flutter/material.dart';

class RingProgressPainter extends CustomPainter {
  RingProgressPainter({required this.progressPercent, required this.color});
  final double progressPercent;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) / 2 - 5;

    final Paint base = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    canvas.drawCircle(center, radius, base);

    final Paint arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final double sweep = (progressPercent.clamp(0, 100) / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant RingProgressPainter oldDelegate) {
    return oldDelegate.progressPercent != progressPercent ||
        oldDelegate.color != color;
  }
}
