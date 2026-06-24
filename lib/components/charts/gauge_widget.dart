import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class GaugeWidget extends StatelessWidget {
  final double percent;
  final double size;
  final double strokeWidth;
  final String? label;
  final String? sublabel;

  const GaugeWidget({
    super.key,
    required this.percent,
    this.size = 140,
    this.strokeWidth = 14,
    this.label,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    final color = clamped >= 100 ? AppColors.danger : clamped >= 80 ? AppColors.warning : AppColors.success;

    return CustomPaint(
      size: Size(size, size),
      painter: _GaugePainter(percent: clamped, color: color, strokeWidth: strokeWidth),
      child: SizedBox(
        width: size, height: size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${clamped.round()}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
            if (label != null) Text(label!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (sublabel != null) Text(sublabel!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  final double strokeWidth;

  _GaugePainter({required this.percent, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * percent / 100, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.percent != percent;
}
