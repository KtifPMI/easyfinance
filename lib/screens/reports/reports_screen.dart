import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/common/simple_bar_chart.dart';
import '../../components/common/simple_pie_chart.dart';
import '../../services/currency_rate_service.dart';
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
        final opsInMonth = store.operations.where((o) => _inPeriod(o, store) && !o.isDeleted).toList();
        final investCatIds = store.categories.where((c) => c.icon == 'invest').map((c) => c.id).toSet();
        double amtRub(o) {
          final acc = store.getAccount(o.accountId);
          final from = acc?.currency ?? o.currency;
          return CurrencyRateService.convert(o.amount, from, 'RUB', store.rates);
        }
        final monthIncome = opsInMonth.where((o) => o.type == 'income' && !investCatIds.contains(o.categoryId)).fold<double>(0, (s, o) => s + amtRub(o));
        final monthExpense = opsInMonth.where((o) => o.type == 'expense' && !investCatIds.contains(o.categoryId)).fold<double>(0, (s, o) => s + amtRub(o));
        final catTotals = store.categories
            .where((c) => c.type == 'expense' && c.icon != 'invest')
            .map((c) => (category: c, total: opsInMonth.where((o) => o.categoryId == c.id && !investCatIds.contains(o.categoryId)).fold<double>(0, (s, o) => s + amtRub(o))))
            .where((e) => e.total > 0)
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));

        final catExpense = catTotals.fold<double>(0, (s, e) => s + e.total);
        final otherTotal = catTotals.length > 6 ? catTotals.skip(6).fold<double>(0, (s, e) => s + e.total) : 0.0;
        final chartSlices = <({String label, double value, Color color})>[];
        for (int i = 0; i < catTotals.length && i < 6; i++) {
          chartSlices.add((label: tCat(context, catTotals[i].category.name), value: catTotals[i].total, color: _chartPalette[i % _chartPalette.length]));
        }
        if (otherTotal > 0) {
          chartSlices.add((label: context.tr('reports.other'), value: otherTotal, color: const Color(0xFF9E9E9E)));
        }

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
                          Text(context.tr('reports.income'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.success)),
                          const SizedBox(height: 4),
                          Text(store.fmt(monthIncome), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textFor(context))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      child: Column(
                        children: [
                          Text(context.tr('reports.expense'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.expense)),
                          const SizedBox(height: 4),
                          Text(store.fmt(monthExpense), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textFor(context))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMonthlyTrendChart(context, store),
              const SizedBox(height: 16),
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
                      ? SimpleBarChart(slices: chartSlices, height: 200, showPercentages: true)
                      : SimplePieChart(
                          slices: chartSlices,
                          size: 220,
                          holeRadius: 0.5,
                          showPercentages: true,
                        ),
                ),
                const SizedBox(height: 16),
                ..._buildCategoryRows(catTotals, catExpense, store),
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

  List<Widget> _buildCategoryRows(List<({dynamic category, double total})> catTotals, double monthExpense, FinanceStore store) {
    final top = catTotals.take(6).toList();
    final otherTotal = catTotals.length > 6 ? catTotals.skip(6).fold<double>(0, (s, e) => s + e.total) : 0.0;
    return [
      ...top.map((e) {
        final percent = monthExpense > 0 ? e.total / monthExpense * 100 : 0.0;
        final color = _chartPalette[top.indexOf(e) % _chartPalette.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/operations',
                arguments: {
                  'categoryId': e.category.id,
                  'dateFrom': _customFrom?.toIso8601String().substring(0, 10) ?? _selectedMonth.toIso8601String().substring(0, 10),
                  'dateTo': _customTo?.toIso8601String().substring(0, 10) ?? DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).toIso8601String().substring(0, 10),
                },
              );
            },
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(tCat(context, e.category.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppColors.textFor(context)))),
                  const SizedBox(width: 8),
                  Text('${percent.round()}% · ${store.fmt(e.total)}', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(height: 6, color: AppColors.borderFor(context), child: FractionallySizedBox(widthFactor: percent / 100, child: Container(color: color))),
              ),
            ],
          ),
          ),
        );
      }),
      if (otherTotal > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: Text(context.tr('reports.other'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context)))),
              const SizedBox(width: 8),
              Text('${monthExpense > 0 ? (otherTotal / monthExpense * 100).round() : 0}% · ${store.fmt(otherTotal)}', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
            ],
          ),
        ),
    ];
  }

  Widget _buildMonthlyTrendChart(BuildContext context, FinanceStore store) {
    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      months.add(m);
    }
    final incomeData = <({String label, double value, Color color})>[];
    final expenseData = <({String label, double value, Color color})>[];
    final netData = <({String label, double value, Color color})>[];

    for (final m in months) {
      final ops = store.operations.where((o) => !o.isDeleted && store.isInMonth(o.date, m)).toList();
      double amtRub(o) {
        final acc = store.getAccount(o.accountId);
        return CurrencyRateService.convert(o.amount, acc?.currency ?? o.currency, 'RUB', store.rates);
      }
      final inv = store.categories.where((c) => c.icon == 'invest').map((c) => c.id).toSet();
      final inc = ops.where((o) => o.type == 'income' && !inv.contains(o.categoryId)).fold(0.0, (s, o) => s + amtRub(o));
      final exp = ops.where((o) => o.type == 'expense' && !inv.contains(o.categoryId)).fold(0.0, (s, o) => s + amtRub(o));
      final monthLabel = context.tr('month.short.${m.month}');
      incomeData.add((label: monthLabel, value: inc, color: AppColors.success));
      expenseData.add((label: monthLabel, value: exp, color: AppColors.expense));
      netData.add((label: monthLabel, value: inc - exp, color: AppColors.primary));
    }

    final maxInc = incomeData.fold(0.0, (m, s) => s.value > m ? s.value : m);
    final maxExp = expenseData.fold(0.0, (m, s) => s.value > m ? s.value : m);
    final maxNet = netData.map((s) => s.value.abs()).fold(0.0, (a, b) => a > b ? a : b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('reports.monthly_trends'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _trendStat(context, context.tr('reports.income'), incomeData.fold(0.0, (s, e) => s + e.value), AppColors.success),
              _trendStat(context, context.tr('reports.expense'), expenseData.fold(0.0, (s, e) => s + e.value), AppColors.expense),
              _trendStat(context, context.tr('reports.net'), netData.fold(0.0, (s, e) => s + e.value), AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          _trendLegend(context),
          const SizedBox(height: 8),
          ...incomeData.asMap().entries.map((e) =>
            _trendLine(context, e.value.label, e.value.value, maxInc > 0 ? maxInc : 1, AppColors.success)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...expenseData.asMap().entries.map((e) =>
            _trendLine(context, e.value.label, e.value.value, maxExp > 0 ? maxExp : 1, AppColors.expense)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...netData.asMap().entries.map((e) =>
            _trendLine(context, e.value.label, e.value.value, maxNet > 0 ? maxNet : 1, AppColors.primary)),
        ],
      ),
    );
  }

  Widget _trendLegend(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 16, height: 3, color: AppColors.success),
        const SizedBox(width: 4),
        Text(context.tr('reports.income'), style: TextStyle(fontSize: 10, color: AppColors.textSecondaryFor(context))),
        const SizedBox(width: 16),
        Container(width: 16, height: 3, color: AppColors.expense),
        const SizedBox(width: 4),
        Text(context.tr('reports.expense'), style: TextStyle(fontSize: 10, color: AppColors.textSecondaryFor(context))),
        const SizedBox(width: 16),
        Container(width: 16, height: 3, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(context.tr('reports.net'), style: TextStyle(fontSize: 10, color: AppColors.textSecondaryFor(context))),
      ],
    );
  }

  Widget _trendLine(BuildContext context, String label, double value, double max, Color color) {
    final fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondaryFor(context)))),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Container(
                height: 4,
                color: AppColors.borderFor(context),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: Container(color: color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 72, child: Text(formatMoney(value), style: TextStyle(fontSize: 10, color: AppColors.textFor(context)), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _trendStat(BuildContext context, String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondaryFor(context))),
        const SizedBox(height: 2),
        Text(formatMoney(value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  static const _chartPalette = [
    const Color(0xFFE53935),
    const Color(0xFF1E88E5),
    const Color(0xFF43A047),
    const Color(0xFFFB8C00),
    const Color(0xFF8E24AA),
    const Color(0xFF00ACC1),
    const Color(0xFFF4511E),
    const Color(0xFF3949AB),
    const Color(0xFFD81B60),
    const Color(0xFF7CB342),
    const Color(0xFF6D4C41),
    const Color(0xFFC0CA33),
    const Color(0xFFFF7043),
    const Color(0xFF26A69A),
    const Color(0xFF5C6BC0),
    const Color(0xFFAB47BC),
    const Color(0xFFFFCA28),
    const Color(0xFF795548),
    const Color(0xFF00897B),
    const Color(0xFFF06292),
  ];
}
