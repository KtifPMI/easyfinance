import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class SimplePieChart extends StatelessWidget {
  final List<({String label, double value, Color color})> slices;
  final double size;
  final double holeRadius;
  final bool showPercentages;

  const SimplePieChart({super.key, required this.slices, this.size = 180, this.holeRadius = 0.55, this.showPercentages = false});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total == 0) return SizedBox(width: size, height: size);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PiePainter(slices: slices, total: total, holeRadius: holeRadius, showPercentages: showPercentages),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<({String label, double value, Color color})> slices;
  final double total;
  final double holeRadius;
  final bool showPercentages;

  _PiePainter({required this.slices, required this.total, required this.holeRadius, this.showPercentages = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    double startAngle = -pi / 2;

    for (final slice in slices) {
      final sweepAngle = (slice.value / total) * 2 * pi;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      if (showPercentages && sweepAngle > 0.25) {
        final pct = (slice.value / total * 100).round();
        if (pct >= 5) {
          final midAngle = startAngle + sweepAngle / 2;
          final labelRadius = radius * 0.7;
          final x = center.dx + labelRadius * cos(midAngle);
          final y = center.dy + labelRadius * sin(midAngle);
          final tp = TextPainter(
            text: TextSpan(text: '$pct%', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
        }
      }

      startAngle += sweepAngle;
    }

    final holePaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * holeRadius, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
