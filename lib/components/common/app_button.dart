import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class AppButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;
  final bool loading;
  final bool disabled;
  final String? variant; // primary, danger, outline, ghost

  const AppButton({super.key, required this.title, this.onPressed, this.loading = false, this.disabled = false, this.variant});

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == null || variant == 'primary';
    final isDanger = variant == 'danger';
    final isOutline = variant == 'outline';
    final bgColor = isDanger ? AppColors.danger : isPrimary ? AppColors.primary : isOutline ? Colors.transparent : Colors.transparent;
    final textColor = isDanger ? Colors.white : isPrimary ? Colors.white : AppColors.primary;
    final border = isOutline ? const BorderSide(color: AppColors.primary, width: 1.5) : null;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (disabled || loading) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: border,
        ),
        child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
