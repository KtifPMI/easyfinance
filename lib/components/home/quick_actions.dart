import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/theme.dart';

class QuickActions extends StatelessWidget {
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final VoidCallback onAddTransfer;
  final VoidCallback onScan;

  const QuickActions({super.key, required this.onAddIncome, required this.onAddExpense, required this.onAddTransfer, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _action(context, Icons.add_circle_outline, context.tr('quick_actions.income'), AppColors.success, onAddIncome),
        const SizedBox(width: 6),
        _action(context, Icons.remove_circle_outline, context.tr('quick_actions.expense'), AppColors.expense, onAddExpense),
        const SizedBox(width: 6),
        _action(context, Icons.swap_horiz, context.tr('quick_actions.transfer'), AppColors.transfer, onAddTransfer),
        const SizedBox(width: 6),
        _action(context, Icons.document_scanner, 'Чек', AppColors.accent, onScan),
      ],
    );
  }

  Widget _action(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardFor(context),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondaryFor(context))),
            ],
          ),
        ),
      ),
    );
  }
}
