import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/operation.dart';
import '../services/currency_rate_service.dart';
import '../theme/theme.dart';

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

  // Цвета, переданные сервером в description (color:#hex), маппятся на фирменные
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
    this.finStateColor,
    this.moneyColor,
    this.budgetColor,
    this.debtColor,
    this.incomeColor,
  });
}

/// Достаёт цвет из HTML-описания тахометра: `color:#bf0000` и маппит
/// серверные цвета подсказок на фирменные цвета приложения.
Color? parseTachColor(String html) {
  final m = RegExp(r'color:#([0-9a-fA-F]{6})').firstMatch(html);
  if (m == null) return null;
  final hex = m.group(1)!.toLowerCase();
  switch (hex) {
    case '106601': return AppColors.success; // зелёный — фирменный
    case 'bf0000': return AppColors.expense; // красный
    case 'd6ab00': return AppColors.warning; // жёлтый
    default:
      return Color(0xFF000000 | int.parse(hex, radix: 16));
  }
}

/// Уровень подсказки (1=плохо, 2=средне, 3=хорошо) из цвета описания API.
/// Цвет и текст совета сервер генерирует вместе, поэтому это точное
/// соответствие сайту.
int? tachTipLevel(String html) {
  final c = parseTachColor(html);
  if (c == null) return null;
  if (c == AppColors.success) return 3;
  if (c == AppColors.warning) return 2;
  if (c == AppColors.expense) return 1;
  return null;
}

int _finLevel(double v) => v >= 66 ? 3 : (v >= 33 ? 2 : 1);
int _moneyLevel(double v) => v >= 83 ? 3 : (v >= 33 ? 2 : 1);
int _budgetLevel(double v) => v <= 33 ? 3 : (v <= 66 ? 2 : 1); // меньше израсходовано → лучше
int _debtLevel(double v) => v <= 30 ? 3 : (v <= 60 ? 2 : 1); // меньше долгов → лучше
int _incomeLevel(double v) => v >= 50 ? 3 : (v >= 25 ? 2 : 1);

/// Собирает FinHealthIndicators из ответа dashboard.get (порядок:
/// finState, money, budget, debt, income). null если данных меньше 5.
/// Подсказки выбираются по уровню из цвета API и сохраняются как ключи
/// переводов (health.*.tipN) — текст всегда на языке приложения.
FinHealthIndicators? finHealthFromServer(List<Map<String, dynamic>> items) {
  if (items.length < 5) return null;
  double val(int i) => (items[i]['value'] as num?)?.toDouble() ?? 0;
  String desc(int i) => (items[i]['description'] as String?) ?? '';
  int level(int i, int fallback(double v)) => tachTipLevel(desc(i)) ?? fallback(val(i));
  String tipKey(String prefix, int l) => 'health.$prefix.tip$l';
  return FinHealthIndicators(
    finState: val(0),
    money: val(1),
    budget: val(2),
    debt: val(3),
    income: val(4),
    finStateTip: tipKey('status', level(0, _finLevel)),
    moneyTip: tipKey('money', level(1, _moneyLevel)),
    budgetTip: tipKey('budget', level(2, _budgetLevel)),
    debtTip: tipKey('debt', level(3, _debtLevel)),
    incomeTip: tipKey('income', level(4, _incomeLevel)),
    finStateColor: parseTachColor(desc(0)),
    moneyColor: parseTachColor(desc(1)),
    budgetColor: parseTachColor(desc(2)),
    debtColor: parseTachColor(desc(3)),
    incomeColor: parseTachColor(desc(4)),
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
