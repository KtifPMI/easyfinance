import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class AppChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onPressed;
  final Color? activeColor;

  const AppChip({super.key, required this.label, this.active = false, required this.onPressed, this.activeColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? (activeColor ?? AppColors.primary) : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? (activeColor ?? AppColors.primary) : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: active ? Colors.white : AppColors.textFor(context))),
      ),
    );
  }
}
