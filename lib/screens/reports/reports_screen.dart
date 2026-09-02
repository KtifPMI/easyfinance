import 'package:flutter/material.dart';
import 'dart:ui' as ui;
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
  final bool showBackButton;
  const ReportsScreen({super.key, this.showBackButton = true});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _selectedMonth;
  DateTime? _customFrom;
  DateTime? _customTo;
  String _chartType = 'pie';
  String _incomeChartType = 'pie';
  String? _preset;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _prevMonth() => setState(() { _preset = null; _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1); });
  void _nextMonth() => setState(() { _preset = null; _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1); });

  void _applyPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _preset = preset;
      switch (preset) {
        case 'week':
          _customFrom = today.subtract(const Duration(days: 6));
          _customTo = today;
        case '3months':
          _customFrom = DateTime(today.year, today.month - 2, 1);
          _customTo = today;
        case 'year':
          _customFrom = DateTime(today.year, 1, 1);
          _customTo = DateTime(today.year, 12, 31);
      }
    });
  }

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
        double amtRub(o) {
          final acc = store.getAccount(o.accountId);
          final from = acc?.currency ?? o.currency;
          return CurrencyRateService.convert(o.amount, from, 'RUB', store.rates);
        }
        final monthIncome = opsInMonth.where((o) => o.type == 'income').fold<double>(0, (s, o) => s + amtRub(o));
        final monthExpense = opsInMonth.where((o) => o.type == 'expense').fold<double>(0, (s, o) => s + amtRub(o));
        final catTotals = store.categories
            .where((c) => c.type == 'expense')
            .map((c) => (category: c, total: opsInMonth.where((o) => o.categoryId == c.id).fold<double>(0, (s, o) => s + amtRub(o))))
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
          chartSlices.add((label: context.tr('reports.other'), value: otherTotal, color: AppColors.textSecondaryFor(context)));
        }

        final incomeCatTotals = store.categories
            .where((c) => c.type == 'income')
            .map((c) => (category: c, total: opsInMonth.where((o) => o.categoryId == c.id).fold<double>(0, (s, o) => s + amtRub(o))))
            .where((e) => e.total > 0)
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));

        final incomeCatTotal = incomeCatTotals.fold<double>(0, (s, e) => s + e.total);
        final incomeOtherTotal = incomeCatTotals.length > 6 ? incomeCatTotals.skip(6).fold<double>(0, (s, e) => s + e.total) : 0.0;
        final incomeChartSlices = <({String label, double value, Color color})>[];
        for (int i = 0; i < incomeCatTotals.length && i < 6; i++) {
          incomeChartSlices.add((label: tCat(context, incomeCatTotals[i].category.name), value: incomeCatTotals[i].total, color: _incomePalette[i % _incomePalette.length]));
        }
        if (incomeOtherTotal > 0) {
          incomeChartSlices.add((label: context.tr('reports.other'), value: incomeOtherTotal, color: AppColors.textSecondaryFor(context)));
        }

        return ScreenScaffold(
          title: context.tr('reports.title'),
          showBackButton: widget.showBackButton,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHint(hintId: 'reports', text: context.tr('hints.reports')),
              Row(
                children: [
                  if (!_isCustomPeriod) IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  Expanded(child: Text(_periodLabel(), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.textFor(context)), textAlign: TextAlign.center)),
                  if (!_isCustomPeriod) IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  TextButton.icon(
                    icon: Icon(_isCustomPeriod ? Icons.clear : Icons.date_range, size: 20, color: _isCustomPeriod ? AppColors.danger : AppColors.primary),
                    label: Text(_isCustomPeriod ? context.tr('reports.clear_period') : context.tr('reports.choose_period'), style: Theme.of(context).textTheme.bodySmall!.copyWith(color: _isCustomPeriod ? AppColors.danger : AppColors.primary)),
                    onPressed: _isCustomPeriod ? () => setState(() { _customFrom = null; _customTo = null; _preset = null; }) : _pickPeriod,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetChip(context, '3months', context.tr('reports.preset.3months')),
                  _presetChip(context, 'year', context.tr('reports.preset.year')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: Column(
                        children: [
                          Text(context.tr('reports.income'), style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: AppColors.success)),
                          const SizedBox(height: 4),
                          Text(store.fmt(monthIncome), style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w700, color: AppColors.textFor(context))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      child: Column(
                        children: [
                          Text(context.tr('reports.expense'), style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: AppColors.expense)),
                          const SizedBox(height: 4),
                          Text(store.fmt(monthExpense), style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w700, color: AppColors.textFor(context))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMonthlyTrendChart(context, store, _selectedMonth, _customFrom, _customTo),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('reports.expense'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
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
                  child: Center(child: Text(context.tr('home.no_expenses'), style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textSecondaryFor(context)))),
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
                ..._buildCategoryRows(catTotals, catExpense, store, _chartPalette),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('reports.income'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.pie_chart, color: _incomeChartType == 'pie' ? AppColors.primary : AppColors.textSecondaryFor(context), size: 22),
                        onPressed: () => setState(() => _incomeChartType = 'pie'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.bar_chart, color: _incomeChartType == 'bar' ? AppColors.primary : AppColors.textSecondaryFor(context), size: 22),
                        onPressed: () => setState(() => _incomeChartType = 'bar'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (incomeCatTotals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(context.tr('reports.no_income'), style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textSecondaryFor(context)))),
                )
              else ...[
                Center(
                  child: _incomeChartType == 'bar'
                    ? SimpleBarChart(slices: incomeChartSlices, height: 200, showPercentages: true)
                    : SimplePieChart(
                        slices: incomeChartSlices,
                        size: 220,
                        holeRadius: 0.5,
                        showPercentages: true,
                      ),
                ),
                const SizedBox(height: 16),
                ..._buildCategoryRows(incomeCatTotals, incomeCatTotal, store, _incomePalette),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _presetChip(BuildContext context, String preset, String label) {
    final active = _preset == preset;
    return ChoiceChip(
      label: Text(label, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: active ? Colors.white : AppColors.textFor(context))),
      selected: active,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.backgroundFor(context),
      onSelected: (_) => _applyPreset(preset),
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
         _preset = null;
       });
     }
  }

  List<Widget> _buildCategoryRows(List<({dynamic category, double total})> catTotals, double monthExpense, FinanceStore store, List<Color> palette) {
    final top = catTotals.take(6).toList();
    final otherTotal = catTotals.length > 6 ? catTotals.skip(6).fold<double>(0, (s, e) => s + e.total) : 0.0;
    return [
      ...top.map((e) {
        final percent = monthExpense > 0 ? e.total / monthExpense * 100 : 0.0;
        final color = palette[top.indexOf(e) % palette.length];
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
                  Expanded(child: Text(tCat(context, e.category.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textFor(context)))),
                  const SizedBox(width: 8),
                  Text('${percent.round()}% · ${store.fmt(e.total)}', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
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
              Expanded(child: Text(context.tr('reports.other'), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textSecondaryFor(context)))),
              const SizedBox(width: 8),
              Text('${monthExpense > 0 ? (otherTotal / monthExpense * 100).round() : 0}% · ${store.fmt(otherTotal)}', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
            ],
          ),
        ),
    ];
  }

  Widget _buildMonthlyTrendChart(BuildContext context, FinanceStore store, DateTime selectedMonth, DateTime? customFrom, DateTime? customTo) {
    final labels = <String>[];
    final expense = <double>[];
    final income = <double>[];
    final net = <double>[];
    final months = <DateTime>[];
    if (customFrom != null || customTo != null) {
      final start = customFrom != null
          ? DateTime(customFrom.year, customFrom.month, 1)
          : DateTime(customTo!.year, customTo!.month, 1);
      final end = customTo != null
          ? DateTime(customTo.year, customTo.month, 1)
          : DateTime(DateTime.now().year, DateTime.now().month, 1);
      var m = start;
      while (!m.isAfter(end)) {
        months.add(m);
        m = DateTime(m.year, m.month + 1, 1);
      }
    } else {
      for (int i = 11; i >= 0; i--) {
        months.add(DateTime(selectedMonth.year, selectedMonth.month - i, 1));
      }
    }
    for (final m in months) {
      final ops = store.operations.where((o) => !o.isDeleted && store.isInMonth(o.date, m)).toList();
      double amtRub(o) {
        final acc = store.getAccount(o.accountId);
        return CurrencyRateService.convert(o.amount, acc?.currency ?? o.currency, 'RUB', store.rates);
      }
      final inc = ops.where((o) => o.type == 'income').fold(0.0, (s, o) => s + amtRub(o));
      final exp = ops.where((o) => o.type == 'expense').fold(0.0, (s, o) => s + amtRub(o));
      labels.add(context.tr('month.short.${m.month}'));
      income.add(inc);
      expense.add(exp);
      net.add(inc - exp);
    }
    final expenseColor = AppColors.expense;
    final incomeColor = AppColors.income;
    final netColor = AppColors.transfer;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('reports.monthly_trends'), style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: LayoutBuilder(
              builder: (ctx, constraints) => CustomPaint(
                size: Size(constraints.maxWidth, 220),
                painter: _ComboChartPainter(
                  labels: labels,
                  expense: expense,
                  income: income,
                  net: net,
                  expenseColor: expenseColor,
                  incomeColor: incomeColor,
                  netColor: netColor,
                  textColor: AppColors.textSecondaryFor(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(expenseColor, context.tr('reports.expense')),
              const SizedBox(width: 16),
              _legendItem(incomeColor, context.tr('reports.income')),
              const SizedBox(width: 16),
              _legendItem(netColor, context.tr('reports.net')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppColors.textSecondaryFor(context))),
      ],
    );
  }

  List<Color> get _chartPalette => AppColors.chartPalette;

  // Доходная диаграмма: первый цвет — наш зелёный, далее все цвета кроме красного и жёлтого.
  static final List<Color> _incomePalette = [
    AppColors.income,
    const Color(0xFF1E88E5),
    const Color(0xFF8E24AA),
    const Color(0xFF00ACC1),
    const Color(0xFF3949AB),
    const Color(0xFFD81B60),
    const Color(0xFF26A69A),
    const Color(0xFF5C6BC0),
    const Color(0xFFAB47BC),
    const Color(0xFF795548),
    const Color(0xFF00897B),
    const Color(0xFFFB8C00),
    const Color(0xFFF4511E),
    const Color(0xFFFF7043),
    const Color(0xFF7CB342),
    const Color(0xFFC0CA33),
    const Color(0xFF6D4C41),
  ];
}

String _fmtAxis(double v) {
  final a = v.abs();
  if (a >= 1e6) {
    final m = v / 1e6;
    return '${m.toStringAsFixed((m.abs() % 1).abs() < 1e-9 ? 0 : 1)}M';
  }
  if (a >= 1e3) {
    final k = v / 1e3;
    return '${k.toStringAsFixed((k.abs() % 1).abs() < 1e-9 ? 0 : 1)}K';
  }
  return v.round().toString();
}

class _ComboChartPainter extends CustomPainter {
  _ComboChartPainter({
    required this.labels,
    required this.expense,
    required this.income,
    required this.net,
    required this.expenseColor,
    required this.incomeColor,
    required this.netColor,
    required this.textColor,
  });

  final List<String> labels;
  final List<double> expense;
  final List<double> income;
  final List<double> net;
  final Color expenseColor;
  final Color incomeColor;
  final Color netColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    if (n == 0) return;
    const left = 44.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 22.0;
    final plotW = size.width - left - right;
    final plotH = size.height - top - bottom;

    final all = <double>[...expense, ...income, ...net];
    double maxAbs = 0;
    for (final v in all) {
      final a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }
    final hi = maxAbs <= 0 ? 1.0 : maxAbs;
    final lo = -hi;
    final span = hi - lo;

    double yFor(double v) => top + (hi - v) / span * plotH;

    final gridPaint = Paint()
      ..color = textColor.withOpacity(0.25)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = textColor.withOpacity(0.5)
      ..strokeWidth = 1;

    final zeroY = yFor(0.0);
    final tickVals = [-hi, -hi / 2, 0.0, hi / 2, hi];
    for (final tv in tickVals) {
      final y = yFor(tv);
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), tv == 0 ? axisPaint : gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: _fmtAxis(tv), style: TextStyle(fontSize: 9, color: textColor)),
        textAlign: TextAlign.right,
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(left - 6 - tp.width, y - tp.height / 2));
    }
    canvas.drawLine(Offset(left, top), Offset(left, size.height - bottom), axisPaint);

    final colW = plotW / n;
    final barW = colW * 0.5;
    final barPaint = Paint()..color = expenseColor;
    for (int i = 0; i < n; i++) {
      final cx = left + (i + 0.5) * colW;
      final y = yFor(expense[i]);
      final topY = expense[i] >= 0 ? y : zeroY;
      final botY = expense[i] >= 0 ? zeroY : y;
      canvas.drawRect(Rect.fromLTRB(cx - barW / 2, topY, cx + barW / 2, botY), barPaint);
    }

    void drawLine(List<double> values, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (int i = 0; i < n; i++) {
        final cx = left + (i + 0.5) * colW;
        final y = yFor(values[i]);
        if (i == 0) {
          path.moveTo(cx, y);
        } else {
          path.lineTo(cx, y);
        }
      }
      canvas.drawPath(path, paint);
      final dot = Paint()..color = color;
      for (int i = 0; i < n; i++) {
        final cx = left + (i + 0.5) * colW;
        canvas.drawCircle(Offset(cx, yFor(values[i])), 2.5, dot);
      }
    }

    drawLine(income, incomeColor);
    drawLine(net, netColor);

    final textStyle = TextStyle(fontSize: 9, color: textColor);
    for (int i = 0; i < n; i++) {
      final cx = left + (i + 0.5) * colW;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - bottom + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _ComboChartPainter old) =>
      old.labels != labels ||
      old.expense != expense ||
      old.income != income ||
      old.net != net ||
      old.expenseColor != expenseColor ||
      old.incomeColor != incomeColor ||
      old.netColor != netColor ||
      old.textColor != textColor;
}
