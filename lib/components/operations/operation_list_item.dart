import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class OperationListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double amount;
  final String type;
  final String? currency;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const OperationListItem({
    super.key,
    required this.title,
    this.subtitle,
    required this.amount,
    required this.type,
    this.currency = 'RUB',
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  String get _amountPrefix {
    if (type == 'income') return '+';
    if (type == 'expense') return '-';
    return '';
  }

  Color _amountColor(BuildContext context) {
    if (type == 'income') return AppColors.income;
    if (type == 'expense') return AppColors.textFor(context);
    return AppColors.transfer;
  }

  @override
  Widget build(BuildContext context) {
    final symbols = {'RUB': '₽', 'USD': '\$', 'EUR': '€'};
    final sym = symbols[currency] ?? currency ?? '₽';
    final amt = amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context)))),
                ],
              ),
            ),
            Text('$_amountPrefix$amt $sym', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _amountColor(context))),
          ],
        ),
      ),
    );
  }
}
