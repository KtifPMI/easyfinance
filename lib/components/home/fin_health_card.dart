import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/theme.dart';
import '../../utils/calc.dart';

class FinHealthCard extends StatelessWidget {
  final FinHealthIndicators indicators;

  const FinHealthCard({super.key, required this.indicators});

  Color _color(double value, List<double> ranges) {
    if (value >= ranges[2]) return AppColors.success;
    if (value >= ranges[1]) return AppColors.warning;
    return AppColors.expense;
  }

  @override
  Widget build(BuildContext context) {
    final moneyRanges = [0.0, 33.0, 83.0];
    final budgetRanges = [0.0, 3.0, 15.0];
    final debtRanges = [0.0, 30.0, 60.0];
    final incomeRanges = [0.0, 25.0, 50.0];

    final finRanges = [0.0, 33.0, 66.0];

    final moneyColor = _color(indicators.money, moneyRanges);
    final budgetColor = _color(indicators.budget, budgetRanges);
    final debtColor = _color(indicators.debt, debtRanges);
    final incomeColor = _color(indicators.income, incomeRanges);
    final finColor = _color(indicators.finState, finRanges);

    final items = [
      ('health.status', Icons.favorite, indicators.finState, finColor, indicators.finStateTip),
      ('health.money', Icons.attach_money, indicators.money, moneyColor, indicators.moneyTip),
      ('health.budget', Icons.bar_chart, indicators.budget, budgetColor, indicators.budgetTip),
      ('health.debts', Icons.account_balance, indicators.debt, debtColor, indicators.debtTip),
      ('health.savings', Icons.savings, indicators.income, incomeColor, indicators.incomeTip),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardFor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('health.title'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: items.map((item) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(context.tr(item.$1), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        content: SingleChildScrollView(child: Text(context.tr(item.$5), style: TextStyle(fontSize: 15))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('common.ok'))),
                        ],
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: item.$4, width: 3)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item.$2, size: 14, color: item.$4),
                            Text('${item.$3.round()}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: item.$4)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(context.tr(item.$1), style: TextStyle(fontSize: 10, color: AppColors.textSecondaryFor(context))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
