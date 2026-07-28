import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class SimplePieChart extends StatelessWidget {
  final List<({String label, double value, Color color})> slices;
  final double size;
  final double holeRadius;

  const SimplePieChart({super.key, required this.slices, this.size = 180, this.holeRadius = 0.55});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total == 0) return SizedBox(width: size, height: size);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PiePainter(slices: slices, total: total, holeRadius: holeRadius),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<({String label, double value, Color color})> slices;
  final double total;
  final double holeRadius;

  _PiePainter({required this.slices, required this.total, required this.holeRadius});

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
