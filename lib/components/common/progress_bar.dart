import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class ProgressBar extends StatelessWidget {
  final double percent;
  final Color? color;
  final double height;

  const ProgressBar({super.key, required this.percent, this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    final barColor = color ?? (clamped >= 100 ? AppColors.danger : clamped >= 80 ? AppColors.warning : AppColors.success);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        width: double.infinity,
        color: AppColors.border,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: clamped / 100,
          child: Container(color: barColor),
        ),
      ),
    );
  }
}
