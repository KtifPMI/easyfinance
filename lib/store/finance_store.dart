import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/financial_event.dart';
import '../models/goal.dart';
import '../models/operation.dart';
import '../models/recommendation.dart';
import '../models/tag.dart';
import '../services/mock_data.dart';

String _genId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

class FinanceStore extends ChangeNotifier {
  List<Account> _accounts = [...mockAccounts];
  List<Operation> _operations = [...mockOperations];
  List<Category> _categories = [...mockCategories];
  List<Budget> _budgets = [...mockBudgets];
  List<Goal> _goals = [...mockGoals];
  List<FinancialEvent> _events = [...mockEvents];
  List<Recommendation> _recommendations = [...mockRecommendations];
  List<Tag> _tags = [...mockTags];

  List<Account> get accounts => _accounts;
  List<Operation> get operations => _operations.where((o) => !o.isDeleted).toList();
  List<Category> get categories => _categories;
  List<Budget> get budgets => _budgets.where((b) => !b.isDeleted).toList();
  List<Goal> get goals => _goals;
  List<FinancialEvent> get events => _events;
  List<Recommendation> get recommendations => _recommendations;
  List<Tag> get tags => _tags;
  bool get isLoading => false;

  Category? getCategory(String? id) => id == null ? null : _categories.cast<Category?>().firstWhere((c) => c!.id == id, orElse: () => null);
  Account? getAccount(String? id) => id == null ? null : _accounts.cast<Account?>().firstWhere((a) => a!.id == id, orElse: () => null);

  double get totalBalance => _accounts.where((a) => a.includeInTotal).fold(0, (s, a) => s + a.balance);
  double get monthIncome {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return _operations.where((o) => o.type == 'income' && !o.isDeleted && _inPeriod(o.date, start, end)).fold(0, (s, o) => s + o.amount);
  }
  double get monthExpense {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return _operations.where((o) => o.type == 'expense' && !o.isDeleted && _inPeriod(o.date, start, end)).fold(0, (s, o) => s + o.amount);
  }

  bool _inPeriod(String dateIso, DateTime start, DateTime end) {
    final d = DateTime.parse(dateIso);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  void addOperation(Operation op) {
    _operations.insert(0, op);
    if (op.type == 'expense') {
      final idx = _accounts.indexWhere((a) => a.id == op.accountId);
      if (idx >= 0) _accounts[idx] = _accounts[idx].copyWith(balance: _accounts[idx].balance - op.amount);
      final bIdx = _budgets.indexWhere((b) => b.categoryId == op.categoryId);
      if (bIdx >= 0) _budgets[bIdx] = _budgets[bIdx].copyWith(spent: _budgets[bIdx].spent + op.amount);
    } else if (op.type == 'income') {
      final idx = _accounts.indexWhere((a) => a.id == op.accountId);
      if (idx >= 0) _accounts[idx] = _accounts[idx].copyWith(balance: _accounts[idx].balance + op.amount);
    } else if (op.type == 'transfer') {
      final fromIdx = _accounts.indexWhere((a) => a.id == op.accountId);
      final toIdx = _accounts.indexWhere((a) => a.id == op.toAccountId);
      if (fromIdx >= 0) _accounts[fromIdx] = _accounts[fromIdx].copyWith(balance: _accounts[fromIdx].balance - op.amount);
      if (toIdx >= 0) _accounts[toIdx] = _accounts[toIdx].copyWith(balance: _accounts[toIdx].balance + op.amount);
    }
    notifyListeners();
  }

  void deleteOperation(String id) {
    final op = _operations.firstWhere((o) => o.id == id);
    if (!op.isDeleted) {
      if (op.type == 'expense') {
        final idx = _accounts.indexWhere((a) => a.id == op.accountId);
        if (idx >= 0) _accounts[idx] = _accounts[idx].copyWith(balance: _accounts[idx].balance + op.amount);
      } else if (op.type == 'income') {
        final idx = _accounts.indexWhere((a) => a.id == op.accountId);
        if (idx >= 0) _accounts[idx] = _accounts[idx].copyWith(balance: _accounts[idx].balance - op.amount);
      }
    }
    final idx = _operations.indexWhere((o) => o.id == id);
    _operations[idx] = _operations[idx].copyWith(isDeleted: true);
    notifyListeners();
  }

  void addBudget(Budget b) {
    _budgets.add(b);
    notifyListeners();
  }

  void deleteBudget(String id) {
    final idx = _budgets.indexWhere((b) => b.id == id);
    if (idx >= 0) _budgets[idx] = _budgets[idx].copyWith(isDeleted: true);
    notifyListeners();
  }

  void addGoal(Goal g) {
    _goals.add(g);
    notifyListeners();
  }

  void updateGoal(String id, {double? currentAmount}) {
    final idx = _goals.indexWhere((g) => g.id == id);
    if (idx >= 0) _goals[idx] = _goals[idx].copyWith(currentAmount: currentAmount);
    notifyListeners();
  }

  void deleteGoal(String id) {
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }
}
