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
        final balance = store.totalBalance;

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

  static const _chartPalette = [
    Color(0xFFE53935), // красный
    Color(0xFF1E88E5), // синий
    Color(0xFF43A047), // зелёный
    Color(0xFFFB8C00), // оранжевый
    Color(0xFF8E24AA), // фиолетовый
    Color(0xFF00ACC1), // бирюзовый
    Color(0xFFF4511E), // коралловый
    Color(0xFF3949AB), // индиго
    Color(0xFFD81B60), // розовый
    Color(0xFF7CB342), // салатовый
    Color(0xFF6D4C41), // коричневый
    Color(0xFFC0CA33), // лайм
    Color(0xFFFF7043), // персиковый
    Color(0xFF26A69A), // мятный
    Color(0xFF5C6BC0), // лавандовый
    Color(0xFFAB47BC), // сиреневый
    Color(0xFFFFCA28), // янтарный
    Color(0xFF795548), // шоколадный
    Color(0xFF00897B), // изумрудный
    Color(0xFFF06292), // малиновый
  ];
}
