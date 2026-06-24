import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class QuickActions extends StatelessWidget {
  final VoidCallback onAddIncome;
  final VoidCallback onAddExpense;
  final VoidCallback onAddTransfer;

  const QuickActions({super.key, required this.onAddIncome, required this.onAddExpense, required this.onAddTransfer});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _action(Icons.add_circle_outline, 'Доход', AppColors.success, onAddIncome),
        const SizedBox(width: 8),
        _action(Icons.remove_circle_outline, 'Расход', AppColors.expense, onAddExpense),
        const SizedBox(width: 8),
        _action(Icons.swap_horiz, 'Перевод', AppColors.transfer, onAddTransfer),
      ],
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
