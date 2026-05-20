import 'package:flutter/material.dart';

import '../../models/attendance_record.dart';
import '../../models/subject.dart';

class TrendLinePainter extends CustomPainter {
  TrendLinePainter(this.subjects);
  final List<Subject> subjects;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 42;
    const double right = 12;
    const double top = 16;
    const double bottom = 30;
    final Rect chart = Rect.fromLTWH(
        left, top, size.width - left - right, size.height - top - bottom);
    final Paint grid = Paint()..color = Colors.grey.shade300;
    for (int i = 0; i <= 5; i++) {
      final double y = chart.bottom - (chart.height * i / 5);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    for (int i = 0; i <= 5; i++) {
      final double x = chart.left + (chart.width * i / 5);
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), grid);
    }
    final List<AttendanceRecord> all = subjects
        .expand((s) => s.records)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (all.isEmpty) {
      final TextPainter tp = TextPainter(
        text: const TextSpan(
            text: 'No data', style: TextStyle(color: Colors.black54)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset(
              size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
      return;
    }

    final Path line = Path();
    int present = 0;
    for (int i = 0; i < all.length; i++) {
      if (all[i].isPresent) present++;
      final double pct = (present / (i + 1)) * 100;
      final double x = chart.left +
          (chart.width * i / (all.length - 1 == 0 ? 1 : (all.length - 1)));
      final double y = chart.bottom - (chart.height * pct / 100);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.blue.shade700
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    final TextPainter yLabel = TextPainter(
      text: const TextSpan(
          text: 'Attendance %',
          style: TextStyle(color: Colors.black87, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    yLabel.paint(canvas, const Offset(4, 6));
  }

  @override
  bool shouldRepaint(covariant TrendLinePainter oldDelegate) => true;
}
