import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/common/simple_bar_chart.dart';
import '../../components/common/simple_pie_chart.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../../utils/translate_category.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _selectedMonth;
  DateTime? _customFrom;
  DateTime? _customTo;
  String _chartType = 'pie';

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _prevMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  void _nextMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));

  bool get _isCustomPeriod => _customFrom != null || _customTo != null;

  bool _inPeriod(op, store) {
    if (_isCustomPeriod) {
      final d = DateTime.tryParse(op.date);
      if (d == null) return false;
      if (_customFrom != null && d.isBefore(_customFrom!)) return false;
      if (_customTo != null) {
        final to = DateTime(_customTo!.year, _customTo!.month, _customTo!.day, 23, 59, 59);
        if (d.isAfter(to)) return false;
      }
      return true;
    }
    return store.isInMonth(op.date, _selectedMonth);
  }

  String _periodLabel() {
    if (_isCustomPeriod) {
      final from = _customFrom != null ? formatDate(_customFrom!.toIso8601String().substring(0, 10)) : '...';
      final to = _customTo != null ? formatDate(_customTo!.toIso8601String().substring(0, 10)) : '...';
      return '$from — $to';
    }
    final months = ['month.long.1', 'month.long.2', 'month.long.3', 'month.long.4', 'month.long.5', 'month.long.6', 'month.long.7', 'month.long.8', 'month.long.9', 'month.long.10', 'month.long.11', 'month.long.12'];
    return '${context.tr(months[_selectedMonth.month - 1])} ${_selectedMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final opsInMonth = store.operations.where((o) => _inPeriod(o, store) && !o.isDeleted);
        final monthIncome = opsInMonth.where((o) => o.type == 'income').fold<double>(0, (s, o) => s + o.amount);
        final monthExpense = opsInMonth.where((o) => o.type == 'expense').fold<double>(0, (s, o) => s + o.amount);
        final balance = store.totalBalance;

        final catTotals = store.categories
            .where((c) => c.type == 'expense')
            .map((c) => (category: c, total: opsInMonth.where((o) => o.categoryId == c.id).fold<double>(0, (s, o) => s + o.amount)))
            .where((e) => e.total > 0)
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));

        final top6 = catTotals.take(6).map((e) => (
          label: tCat(context, e.category.name),
          value: e.total,
          color: _parseColor(e.category.color),
        )).toList();

        return ScreenScaffold(
          title: context.tr('reports.title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHint(hintId: 'reports', text: context.tr('hints.reports')),
              Row(
                children: [
                  if (!_isCustomPeriod) IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  Expanded(child: Text(_periodLabel(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textFor(context)), textAlign: TextAlign.center)),
                  if (!_isCustomPeriod) IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  IconButton(
                    icon: Icon(_isCustomPeriod ? Icons.clear : Icons.date_range, size: 20, color: _isCustomPeriod ? AppColors.danger : AppColors.textSecondaryFor(context)),
                    onPressed: _isCustomPeriod ? () => setState(() { _customFrom = null; _customTo = null; }) : _pickPeriod,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
                          Text(store.fmt(monthIncome), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success)),
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
                          Text(store.fmt(monthExpense), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.expense)),
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
                    Text(store.fmt(balance), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: balance >= 0 ? AppColors.success : AppColors.expense)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('reports.by_category'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.pie_chart, color: _chartType == 'pie' ? AppColors.primary : AppColors.textSecondaryFor(context), size: 22),
                        onPressed: () => setState(() => _chartType = 'pie'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.bar_chart, color: _chartType == 'bar' ? AppColors.primary : AppColors.textSecondaryFor(context), size: 22),
                        onPressed: () => setState(() => _chartType = 'bar'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (catTotals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(context.tr('home.no_expenses'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context)))),
                )
              else ...[
                Center(
                  child: _chartType == 'bar'
                      ? SimpleBarChart(slices: top6, height: 180, showPercentages: true)
                      : SimplePieChart(
                          slices: top6,
                          size: 200,
                          holeRadius: 0.55,
                          showPercentages: true,
                        ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: catTotals.take(6).map((e) {
                    final color = _parseColor(e.category.color);
                    final pct = monthExpense > 0 ? (e.total / monthExpense * 100).round() : 0;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('${tCat(context, e.category.name)} $pct%', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryFor(context))),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                ..._buildCategoryRows(catTotals, monthExpense),
              ],
            ],
          ),
        );
      },
    );
  }

  void _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customFrom != null && _customTo != null
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _customFrom = picked.start;
        _customTo = picked.end;
      });
    }
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
                  Text(tCat(context, e.category.name), style: TextStyle(fontSize: 14, color: AppColors.textFor(context))),
                  Text('${percent.round()}% · ${store.fmt(e.total)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
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
              Text('${monthExpense > 0 ? (otherTotal / monthExpense * 100).round() : 0}% · ${store.fmt(otherTotal)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
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
