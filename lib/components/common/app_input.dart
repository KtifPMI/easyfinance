import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class AppInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? error;
  final bool enabled;
  final int? maxLines;

  const AppInput({super.key, required this.label, this.hint, this.controller, this.obscureText = false, this.keyboardType, this.error, this.enabled = true, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w400)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: enabled,
          maxLines: maxLines,
          style: TextStyle(fontSize: 15, color: AppColors.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 15, color: AppColors.textSecondary.withValues(alpha: 0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: error != null ? AppColors.danger : AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (error != null) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(error!, style: TextStyle(fontSize: 11, color: AppColors.danger)),
        ),
      ],
    );
  }
}
