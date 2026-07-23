import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _prevMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  void _nextMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));

  String _monthLabel() {
    final months = ['month.long.1', 'month.long.2', 'month.long.3', 'month.long.4', 'month.long.5', 'month.long.6', 'month.long.7', 'month.long.8', 'month.long.9', 'month.long.10', 'month.long.11', 'month.long.12'];
    return '${context.tr(months[_selectedMonth.month - 1])} ${_selectedMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final isCurrent = _selectedMonth.month == DateTime.now().month && _selectedMonth.year == DateTime.now().year;
        final opsInMonth = store.operations.where((o) => store.isInMonth(o.date, _selectedMonth));
        final monthIncome = opsInMonth.where((o) => o.type == 'income').fold<double>(0, (s, o) => s + o.amount);
        final monthExpense = opsInMonth.where((o) => o.type == 'expense').fold<double>(0, (s, o) => s + o.amount);
        final balance = store.totalBalance;

        final catTotals = store.categories
            .where((c) => c.type == 'expense')
            .map((c) => (category: c, total: opsInMonth.where((o) => o.categoryId == c.id).fold<double>(0, (s, o) => s + o.amount)))
            .where((e) => e.total > 0)
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));

        return ScreenScaffold(
          title: context.tr('reports.title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHint(hintId: 'reports', text: 'Аналитика за месяц: доходы, расходы, структура трат по категориям и динамика остатка на счетах.'),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                  Text(_monthLabel(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                  if (!isCurrent) IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
                  if (!isCurrent)
                    TextButton(
                      onPressed: () => setState(() => _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1)),
                      child: Text(context.tr('reports.today')),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(
                        children: [
                          Icon(Icons.arrow_downward, color: AppColors.success, size: 28),
                          const SizedBox(height: 4),
                          Text(context.tr('reports.income'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                          const SizedBox(height: 4),
                          Text(formatMoney(monthIncome), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success)),
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
                          Text(context.tr('reports.expense'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                          const SizedBox(height: 4),
                          Text(formatMoney(monthExpense), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.expense)),
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
                    Text(context.tr('reports.balance'), style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
                    Text(formatMoney(balance), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: balance >= 0 ? AppColors.success : AppColors.expense)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(context.tr('reports.by_category'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              const SizedBox(height: 12),
              if (catTotals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(context.tr('home.no_expenses'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context)))),
                )
              else
                ..._buildCategoryRows(catTotals, monthExpense),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildCategoryRows(List<({dynamic category, double total})> catTotals, double monthExpense) {
    final top = catTotals.take(6).toList();
    final otherTotal = catTotals.length > 6 ? catTotals.skip(6).fold<double>(0, (s, e) => s + e.total) : 0.0;
    return [
      ...top.map((e) {
        final percent = monthExpense > 0 ? e.total / monthExpense * 100 : 0.0;
        final color = _parseColor(e.category.color);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.category.name, style: TextStyle(fontSize: 14, color: AppColors.textFor(context))),
                  Text('${percent.round()}% · ${formatMoney(e.total)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(height: 6, color: AppColors.borderFor(context), child: FractionallySizedBox(widthFactor: percent / 100, child: Container(color: color))),
              ),
            ],
          ),
        );
      }),
      if (otherTotal > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('reports.other'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
              Text('${monthExpense > 0 ? (otherTotal / monthExpense * 100).round() : 0}% · ${formatMoney(otherTotal)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
            ],
          ),
        ),
    ];
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
