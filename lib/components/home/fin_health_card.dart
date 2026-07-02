import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
      (context.tr('health.status'), Icons.favorite, indicators.finState, 60),
      (context.tr('health.liquidity'), Icons.water_drop, indicators.money, 50),
      (context.tr('health.budget'), Icons.bar_chart, indicators.budget, 50),
      (context.tr('health.debts'), Icons.account_balance, indicators.debt, 70),
      (context.tr('health.savings'), Icons.savings, indicators.savings, 40),
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
          Text(context.tr('health.title'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: items.map((item) {
              final (label, icon, value, threshold) = item;
              final c = _color(value, threshold);
              return Column(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 3)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 14, color: c),
                        Text('$value%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(label, style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(context.tr('health.detail'), style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
