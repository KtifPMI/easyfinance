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
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;

  const AppInput({super.key, required this.label, this.hint, this.controller, this.obscureText = false, this.keyboardType, this.error, this.enabled = true, this.maxLines = 1, this.onSubmitted, this.onTap, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context), fontWeight: FontWeight.w400)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: enabled,
          maxLines: maxLines,
          onSubmitted: onSubmitted,
          onTap: onTap,
          readOnly: readOnly,
          style: TextStyle(fontSize: 16, color: AppColors.textFor(context)),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.cardFor(context),
            hintText: hint,
            hintStyle: TextStyle(fontSize: 16, color: AppColors.textSecondaryFor(context).withValues(alpha: 0.6)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: error != null ? AppColors.danger : AppColors.borderFor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderFor(context)),
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
          child: Text(error!, style: TextStyle(fontSize: 12, color: AppColors.danger)),
        ),
      ],
    );
  }
}
