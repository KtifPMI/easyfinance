import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class SimplePieChart extends StatelessWidget {
  final List<({String label, double value, Color color})> slices;
  final double size;
  final double holeRadius;
  final bool showPercentages;
  final void Function(int index)? onSliceTap;

  const SimplePieChart({
    super.key,
    required this.slices,
    this.size = 180,
    this.holeRadius = 0.55,
    this.showPercentages = false,
    this.onSliceTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total == 0) return SizedBox(width: size, height: size);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        if (onSliceTap == null) return;
        final local = details.localPosition;
        final center = Offset(size / 2, size / 2);
        final dx = local.dx - center.dx;
        final dy = local.dy - center.dy;
        final dist = sqrt(dx * dx + dy * dy);
        final radius = size / 2;
        if (dist < radius * holeRadius || dist > radius) return;
        var angle = atan2(dy, dx) + pi / 2;
        if (angle < 0) angle += 2 * pi;
        double accumulated = 0;
        for (int i = 0; i < slices.length; i++) {
          final sweep = (slices[i].value / total) * 2 * pi;
          if (angle <= accumulated + sweep) {
            onSliceTap!(i);
            return;
          }
          accumulated += sweep;
        }
      },
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PiePainter(
            slices: slices,
            total: total,
            holeRadius: holeRadius,
            showPercentages: showPercentages,
            holeColor: AppColors.backgroundFor(context),
          ),
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<({String label, double value, Color color})> slices;
  final double total;
  final double holeRadius;
  final bool showPercentages;
  final Color holeColor;

  _PiePainter({required this.slices, required this.total, required this.holeRadius, this.showPercentages = false, required this.holeColor});

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
          // Place the label exactly in the middle of the colored ring band.
          final labelRadius = radius * (holeRadius + 1) / 2;
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
      ..color = holeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * holeRadius, holePaint);
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) {
    if (old.total != total) return true;
    if (old.slices.length != slices.length) return true;
    for (int i = 0; i < slices.length; i++) {
      if (old.slices[i].value != slices[i].value || old.slices[i].label != slices[i].label) return true;
    }
    return false;
  }
}
