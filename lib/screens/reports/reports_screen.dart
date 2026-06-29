import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final income = store.monthIncome;
        final expense = store.monthExpense;
        final balance = store.totalBalance;

        return ScreenScaffold(
          title: context.tr('reports.title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('reports.this_month'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(
                        children: [
                          Icon(Icons.arrow_downward, color: AppColors.success, size: 28),
                          const SizedBox(height: 4),
                          Text(context.tr('reports.income'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(formatMoney(income), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      child: Column(
                        children: [
                          Icon(Icons.arrow_upward, color: AppColors.expense, size: 28),
                          const SizedBox(height: 4),
                          Text(context.tr('reports.expense'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(formatMoney(expense), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.expense)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('reports.balance'), style: TextStyle(fontSize: 15, color: AppColors.text)),
                    Text(formatMoney(balance), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: balance >= 0 ? AppColors.success : AppColors.expense)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(context.tr('reports.by_category'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 12),
              ...store.categories.where((c) => c.type == 'expense').take(6).map((cat) {
                final total = store.operations.where((o) => o.categoryId == cat.id && !o.isDeleted).fold<double>(0, (s, o) => s + o.amount);
                if (total == 0) return const SizedBox.shrink();
                final percent = expense > 0 ? total / expense * 100 : 0.0;
                final color = _parseColor(cat.color);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cat.name, style: TextStyle(fontSize: 14, color: AppColors.text)),
                          Text('${percent.round()}% · ${formatMoney(total)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(height: 6, color: AppColors.border, child: FractionallySizedBox(widthFactor: percent / 100, child: Container(color: color))),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
