import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/operation.dart';
import '../services/currency_rate_service.dart';

class FinHealthIndicators {
  final double finState;
  final double money;
  final double budget;
  final double debt;
  final double income;
  final String moneyTip;
  final String budgetTip;
  final String debtTip;
  final String incomeTip;
  final String finStateTip;

  // Серверные тексты из dashboard.get (title/description со стр. сайта)
  final String finStateTitle;
  final String moneyTitle;
  final String budgetTitle;
  final String debtTitle;
  final String incomeTitle;
  final String finStateDescription;
  final String moneyDescription;
  final String budgetDescription;
  final String debtDescription;
  final String incomeDescription;

  // Цвета, переданные сервером в description (color:#hex)
  final Color? finStateColor;
  final Color? moneyColor;
  final Color? budgetColor;
  final Color? debtColor;
  final Color? incomeColor;

  FinHealthIndicators({
    required this.finState,
    required this.money,
    required this.budget,
    required this.debt,
    required this.income,
    this.moneyTip = '',
    this.budgetTip = '',
    this.debtTip = '',
    this.incomeTip = '',
    this.finStateTip = '',
    this.finStateTitle = '',
    this.moneyTitle = '',
    this.budgetTitle = '',
    this.debtTitle = '',
    this.incomeTitle = '',
    this.finStateDescription = '',
    this.moneyDescription = '',
    this.budgetDescription = '',
    this.debtDescription = '',
    this.incomeDescription = '',
    this.finStateColor,
    this.moneyColor,
    this.budgetColor,
    this.debtColor,
    this.incomeColor,
  });

  bool get hasServerTexts => moneyTitle.isNotEmpty || finStateTitle.isNotEmpty;
}

String stripHtmlTags(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&mdash;', '—')
      .replaceAll('&laquo;', '«')
      .replaceAll('&raquo;', '»')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Достаёт цвет из HTML-описания тахометра: `color:#bf0000` → красный.
Color? parseTachColor(String html) {
  final m = RegExp(r'color:#([0-9a-fA-F]{6})').firstMatch(html);
  if (m == null) return null;
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

/// Собирает FinHealthIndicators из ответа dashboard.get (порядок:
/// finState, money, budget, debt, income). null если данных меньше 5.
FinHealthIndicators? finHealthFromServer(List<Map<String, dynamic>> items) {
  if (items.length < 5) return null;
  double val(int i) => (items[i]['value'] as num?)?.toDouble() ?? 0;
  String txt(int i, String key) => (items[i][key] as String?) ?? '';
  return FinHealthIndicators(
    finState: val(0),
    money: val(1),
    budget: val(2),
    debt: val(3),
    income: val(4),
    finStateTitle: txt(0, 'title'),
    moneyTitle: txt(1, 'title'),
    budgetTitle: txt(2, 'title'),
    debtTitle: txt(3, 'title'),
    incomeTitle: txt(4, 'title'),
    finStateDescription: txt(0, 'description'),
    moneyDescription: txt(1, 'description'),
    budgetDescription: txt(2, 'description'),
    debtDescription: txt(3, 'description'),
    incomeDescription: txt(4, 'description'),
    finStateColor: parseTachColor(txt(0, 'description')),
    moneyColor: parseTachColor(txt(1, 'description')),
    budgetColor: parseTachColor(txt(2, 'description')),
    debtColor: parseTachColor(txt(3, 'description')),
    incomeColor: parseTachColor(txt(4, 'description')),
  );
}

FinHealthIndicators calcFinHealth(List<Account> accounts, List<Operation> operations, List<Budget> budgets, Map<String, double> rates) {
  final now = DateTime.now();

  final moneyMonths = _calcMoneyMonths(accounts, operations, now, rates);
  final moneyVal = (moneyMonths / 6.0 * 100).clamp(0.0, 100.0);
  final budgetRaw = _calcBudget(budgets);
  final budgetVal = budgetRaw.clamp(0.0, 100.0);
  final debtRaw = _calcDebt(accounts, operations, now, rates);
  final debtVal = debtRaw.clamp(0.0, 100.0);
  final incomeRaw = _calcIncomeRaw(operations, accounts, now, rates);
  final incomeVal = (incomeRaw / 20.0 * 100).clamp(0.0, 100.0);
  final finStateVal = _calcFinState(moneyMonths, budgetRaw, debtRaw, incomeRaw);

  return FinHealthIndicators(
    finState: finStateVal,
    money: moneyVal,
    budget: budgetVal,
    debt: debtVal,
    income: incomeVal,
    moneyTip: _moneyTip(moneyMonths),
    budgetTip: _budgetTip(budgetRaw),
    debtTip: _debtTip(debtRaw),
    incomeTip: _incomeTip(incomeRaw),
    finStateTip: _finStateTip(finStateVal),
  );
}

bool _isMoneyAccountType(String type) => groupForType(type) == 'money';

double _opToRub(Operation o, List<Account> accounts, Map<String, double> rates) {
  final acc = accounts.where((a) => a.id == o.accountId).firstOrNull;
  final cur = acc?.currency ?? o.currency;
  return CurrencyRateService.convert(o.amount, cur, 'RUB', rates);
}

double _calcMoneyMonths(List<Account> accounts, List<Operation> operations, DateTime now, Map<String, double> rates) {
  double moneyBalance = 0;
  for (final a in accounts) {
    if (!a.includeInTotal || a.isArchived) continue;
    final balanceRub = CurrencyRateService.convert(a.balance, a.currency, 'RUB', rates);
    if (_isMoneyAccountType(a.type)) {
      moneyBalance += balanceRub;
    }
    if (a.type == 'credit_card' && a.balance > 0) {
      moneyBalance += balanceRub;
    }
  }
  if (moneyBalance <= 0) return 0;

  final monthStart = DateTime(now.year, now.month - 1, now.day);
  final periodOps = operations.where((o) {
    if (o.isDeleted) return false;
    final d = DateTime.tryParse(o.date);
    return d != null && !d.isBefore(monthStart) && !d.isAfter(now);
  }).toList();

  final expenses = periodOps
      .where((o) => o.type == 'expense')
      .fold<double>(0, (s, o) => s + _opToRub(o, accounts, rates));
  final creditPayments = _calcCreditPayments(periodOps, accounts, rates);
  final avgMonthlyExpense = (expenses + creditPayments) / 3;

  if (avgMonthlyExpense <= 0) return 6;
  return (moneyBalance / avgMonthlyExpense).clamp(0.0, 6.0);
}

double _calcCreditPayments(List<Operation> ops, List<Account> accounts, Map<String, double> rates) {
  final creditAccountIds = accounts.where((a) => groupForType(a.type) == 'owed_by_me').map((a) => a.id).toSet();
  return ops.where((o) =>
    o.type == 'transfer' &&
    o.toAccountId != null &&
    creditAccountIds.contains(o.toAccountId) &&
    !o.isDeleted
  ).fold<double>(0, (s, o) => s + _opToRub(o, accounts, rates));
}

double _calcBudget(List<Budget> budgets) {
  final active = budgets.where((b) => !b.isDeleted).toList();
  final totalPlanned = active.fold<double>(0, (s, b) => s + b.limit);
  final totalSpent = active.fold<double>(0, (s, b) => s + b.spent);
  if (totalSpent == 0) return 100;
  if (totalPlanned == 0) return 0;
  return ((1 - totalSpent / totalPlanned) * 100).clamp(0.0, 100.0);
}

double _calcDebt(List<Account> accounts, List<Operation> operations, DateTime now, Map<String, double> rates) {
  final periodStart = DateTime(now.year, now.month - 1, now.day);

  final periodOps = operations.where((o) {
    if (o.isDeleted) return false;
    final d = DateTime.tryParse(o.date);
    return d != null && !d.isBefore(periodStart) && !d.isAfter(now);
  }).toList();

  final creditPayments = _calcCreditPayments(periodOps, accounts, rates);
  final income = periodOps
      .where((o) => o.type == 'income')
      .fold<double>(0, (s, o) => s + _opToRub(o, accounts, rates));
  if (creditPayments == 0) return 100;
  if (income == 0) return 0;

  return ((1 - creditPayments / income) * 100).clamp(0.0, 100.0);
}

double _calcIncomeRaw(List<Operation> operations, List<Account> accounts, DateTime now, Map<String, double> rates) {
  final periodStart = DateTime(now.year, now.month - 1, now.day);

  final periodOps = operations.where((o) {
    if (o.isDeleted) return false;
    final d = DateTime.tryParse(o.date);
    return d != null && !d.isBefore(periodStart) && !d.isAfter(now);
  }).toList();

  final income3m = periodOps
      .where((o) => o.type == 'income')
      .fold<double>(0, (s, o) => s + _opToRub(o, accounts, rates));
  if (income3m == 0) return 0;

  final expenses3m = periodOps
      .where((o) => o.type == 'expense')
      .fold<double>(0, (s, o) => s + _opToRub(o, accounts, rates));
  final creditPayments = _calcCreditPayments(periodOps, accounts, rates);
  final totalExp = expenses3m + creditPayments;
  if (totalExp == 0) return 20;

  return ((income3m / totalExp) - 1) * 500;
}

double _calcFinState(double moneyMonths, double budget, double debt, double incomeRaw) {
  double zoneScore(double value, List<double> ranges) {
    for (int i = 0; i < ranges.length - 1; i++) {
      if (value <= ranges[i + 1]) {
        final span = ranges[i + 1] - ranges[i];
        final normalized = span > 0 ? ((value - ranges[i]) / span).clamp(0.0, 1.0) : 0.0;
        return (i + normalized).clamp(0.0, 3.0);
      }
    }
    return 3.0;
  }

  final moneyWeighted = zoneScore(moneyMonths, [0.0, 2.0, 5.0, 6.0]) * 35;
  final budgetWeighted = zoneScore(budget, [0.0, 3.0, 15.0, 100.0]) * 20;
  final debtWeighted = zoneScore(debt, [0.0, 30.0, 60.0, 100.0]) * 15;
  final incomeWeighted = zoneScore(incomeRaw, [0.0, 5.0, 10.0, 20.0]) * 30;

  return ((moneyWeighted + budgetWeighted + debtWeighted + incomeWeighted) / 3).clamp(0.0, 100.0);
}

String _moneyTip(double months) {
  if (months <= 2) return 'health.money.tip1';
  if (months <= 5) return 'health.money.tip2';
  return 'health.money.tip3';
}

String _budgetTip(double value) {
  if (value <= 3) return 'health.budget.tip1';
  if (value <= 15) return 'health.budget.tip2';
  return 'health.budget.tip3';
}

String _debtTip(double value) {
  if (value <= 30) return 'health.debt.tip1';
  if (value <= 60) return 'health.debt.tip2';
  return 'health.debt.tip3';
}

String _incomeTip(double value) {
  if (value <= 5) return 'health.income.tip1';
  if (value <= 10) return 'health.income.tip2';
  return 'health.income.tip3';
}

String _finStateTip(double value) {
  if (value <= 33) return 'health.status.tip1';
  if (value <= 66) return 'health.status.tip2';
  return 'health.status.tip3';
}

bool isInPeriod(String dateIso, DateTime start, DateTime end) {
  final d = DateTime.tryParse(dateIso);
  if (d == null) return false;
  return !d.isBefore(start) && !d.isAfter(end);
}

double sumByType(List<Operation> operations, String type) {
  return operations.where((o) => o.type == type && !o.isDeleted).fold<double>(0, (sum, o) => sum + o.amount);
}

double getTotalBalance(List<Account> accounts, Map<String, double> rates) {
  return accounts
      .where((a) => a.includeInTotal && !a.isArchived)
      .fold<double>(0, (sum, a) => sum + CurrencyRateService.convert(a.balance, a.currency, 'RUB', rates));
}

double getBudgetPercent(Budget budget) {
  if (budget.limit <= 0) return 0;
  return (budget.spent / budget.limit) * 100;
}

double getBudgetForecastPercent(Budget budget) {
  if (budget.limit <= 0) return 0;
  final now = DateTime.now();
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final daysPassed = now.day.clamp(1, daysInMonth);
  if (daysPassed <= 0 || budget.spent <= 0) return 0;
  final dailyRate = budget.spent / daysPassed;
  final forecast = dailyRate * daysInMonth;
  return forecast / budget.limit * 100;
}

Color budgetForecastColor(double forecastPercent) {
  if (forecastPercent > 90) return const Color(0xFFEF4444);
  if (forecastPercent > 70) return const Color(0xFFF59E0B);
  return const Color(0xFF16A34A);
}
