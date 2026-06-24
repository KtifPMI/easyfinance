import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../utils/calc.dart';

class FinHealthCard extends StatelessWidget {
  final FinHealthIndicators indicators;

  const FinHealthCard({super.key, required this.indicators});

  Color _color(int value, int threshold) {
    if (value >= threshold) return AppColors.success;
    if (value >= threshold ~/ 2) return AppColors.warning;
    return AppColors.expense;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Состояние', Icons.favorite, indicators.finState, 60),
      ('Ликвидность', Icons.water_drop, indicators.money, 50),
      ('Бюджет', Icons.bar_chart, indicators.budget, 50),
      ('Долги', Icons.account_balance, indicators.debt, 70),
      ('Сбережения', Icons.savings, indicators.savings, 40),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Финансовое состояние', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: items.map((item) {
              final (label, icon, value, threshold) = item;
              final c = _color(value, threshold);
              return Column(
                children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 3)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 16, color: c),
                        Text('$value%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text('Ликвидность: запас на 3 мес. · Сбережения: норма 20% дохода', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
