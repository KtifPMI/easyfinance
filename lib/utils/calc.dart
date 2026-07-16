import '../models/account.dart';
import '../models/budget.dart';
import '../models/operation.dart';

class FinHealthIndicators {
  final int finState;
  final int money;
  final int budget;
  final int debt;
  final int savings;

  FinHealthIndicators({required this.finState, required this.money, required this.budget, required this.debt, required this.savings});
}

FinHealthIndicators calcFinHealth(List<Account> accounts, List<Operation> operations, List<Budget> budgets) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  final monthOps = operations.where((o) => !o.isDeleted && isInPeriod(o.date, start, end)).toList();
  final monthIncome = sumByType(monthOps, 'income');
  final monthExpense = sumByType(monthOps, 'expense');
  final totalBalance = getTotalBalance(accounts);

  final avgExpense = monthExpense > 0 ? monthExpense : 1.0;
  final liquidityMonths = totalBalance / avgExpense;
  final money = (liquidityMonths / 3 * 100).clamp(0, 100).round();

  double budgetScore = 100;
  final totalPlanned = budgets.fold<double>(0, (s, b) => s + b.limit);
  final totalSpent = budgets.fold<double>(0, (s, b) => s + b.spent);
  if (totalPlanned > 0) {
    final ratio = totalSpent / totalPlanned;
    budgetScore = ((2 - ratio) * 50).clamp(0, 100).round().toDouble();
  }

  double debtScore = 100;
  final creditBalance = accounts
      .where((a) => a.type == 'credit')
      .fold<double>(0, (s, a) => s + a.balance.abs());
  if (creditBalance > 0) {
    debtScore = ((1 - creditBalance / (monthIncome > 0 ? monthIncome : creditBalance)) * 100).clamp(0, 100).round().toDouble();
  }

  double savings = 0;
  if (monthIncome > 0) {
    final savingsRate = (monthIncome - monthExpense) / monthIncome;
    savings = (savingsRate / 0.2 * 100).clamp(0, 100);
  }

  final finState = ((money + budgetScore + debtScore + savings) / 4).round();

  return FinHealthIndicators(finState: finState, money: money, budget: budgetScore.round(), debt: debtScore.round(), savings: savings.round());
}

bool isInPeriod(String dateIso, DateTime start, DateTime end) {
  final d = DateTime.tryParse(dateIso);
  if (d == null) return false;
  return !d.isBefore(start) && !d.isAfter(end);
}

double sumByType(List<Operation> operations, String type) {
  return operations.where((o) => o.type == type && !o.isDeleted).fold<double>(0, (sum, o) => sum + o.amount);
}

double getTotalBalance(List<Account> accounts) {
  return accounts.where((a) => a.includeInTotal).fold<double>(0, (sum, a) => sum + a.balance);
}

double getBudgetPercent(Budget budget) {
  if (budget.limit <= 0) return 0;
  return (budget.spent / budget.limit) * 100;
}
