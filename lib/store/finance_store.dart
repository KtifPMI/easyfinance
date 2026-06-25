import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart' as cat;
import '../models/financial_event.dart';
import '../models/goal.dart';
import '../models/operation.dart';
import '../models/recommendation.dart';
import '../models/tag.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';

class FinanceStore extends ChangeNotifier {
  final AuthService authService;
  final ApiClient apiClient;
  ApiService? _apiService;

  List<Account> _accounts = [];
  List<Operation> _operations = [];
  List<cat.Category> _categories = [];
  List<Budget> _budgets = [];
  List<Goal> _goals = [...mockGoals];
  List<FinancialEvent> _events = [...mockEvents];
  List<Recommendation> _recommendations = [...mockRecommendations];
  List<Tag> _tags = [];
  bool _isLoading = false;
  bool _useMock = true;
  String? _error;

  FinanceStore({required this.authService, required this.apiClient}) {
    _loadFromMock();
  }

  void _loadFromMock() {
    _accounts = [...mockAccounts];
    _operations = [...mockOperations];
    _categories = [...mockCategories];
    _budgets = [...mockBudgets];
    _tags = [...mockTags];
    _useMock = true;
  }

  bool get isAuthenticated => authService.isAuthenticated;
  List<Account> get accounts => _accounts;
  List<Operation> get operations => _operations.where((o) => !o.isDeleted).toList();
  List<cat.Category> get categories => _categories;
  List<Budget> get budgets => _budgets.where((b) => !b.isDeleted).toList();
  List<Goal> get goals => _goals;
  List<FinancialEvent> get events => _events;
  List<Recommendation> get recommendations => _recommendations;
  List<Tag> get tags => _tags;
  bool get isLoading => _isLoading;
  bool get useMock => _useMock;
  String? get error => _error;

  cat.Category? getCategory(String? id) => id == null ? null : _categories.cast<cat.Category?>().firstWhere((c) => c!.id == id, orElse: () => null);
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

  Future<void> fetchAllData() async {
    if (!authService.isAuthenticated) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = authService.apiService;
      final results = await Future.wait([
        api.getAccounts(),
        api.getOperations(),
        api.getCategories(),
        api.getTags(),
      ]);
      _accounts = results[0] as List<Account>;
      _operations = results[1] as List<Operation>;
      _categories = results[2] as List<cat.Category>;
      _tags = results[3] as List<Tag>;
      _useMock = false;
    } on ApiException catch (e) {
      _error = e.message;
      _loadFromMock();
    } catch (e) {
      _error = e.toString();
      _loadFromMock();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addOperation(Operation op) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        await authService.apiService.addOperation({
          'operations': [{
            'account_id': op.accountId,
            'category_id': op.categoryId,
            'sum': op.amount.toString(),
            'date': op.date,
            'type': op.type,
            'comment': op.comment ?? '',
            'client_id': op.id,
          }]
        });
      } catch (_) {}
    }
    _operations.insert(0, op);
    _updateBalancesOnAdd(op);
    notifyListeners();
  }

  Future<void> deleteOperation(String id) async {
    final op = _operations.firstWhere((o) => o.id == id);
    if (!_useMock && authService.isAuthenticated) {
      try {
        await authService.apiService.setOperation({
          'operations': [{
            'id': op.id,
            'deleted_at': DateTime.now().toIso8601String(),
          }]
        });
      } catch (_) {}
    }
    if (!op.isDeleted) _updateBalancesOnDelete(op);
    final idx = _operations.indexWhere((o) => o.id == id);
    _operations[idx] = _operations[idx].copyWith(isDeleted: true);
    notifyListeners();
  }

  void _updateBalancesOnAdd(Operation op) {
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
  }

  void _updateBalancesOnDelete(Operation op) {
    if (op.type == 'expense') {
      final idx = _accounts.indexWhere((a) => a.id == op.accountId);
      if (idx >= 0) _accounts[idx] = _accounts[idx].copyWith(balance: _accounts[idx].balance + op.amount);
    } else if (op.type == 'income') {
      final idx = _accounts.indexWhere((a) => a.id == op.accountId);
      if (idx >= 0) _accounts[idx] = _accounts[idx].copyWith(balance: _accounts[idx].balance - op.amount);
    }
  }

  Future<void> addBudget(Budget b) async {
    _budgets.add(b);
    notifyListeners();
  }

  Future<void> deleteBudget(String id) async {
    final idx = _budgets.indexWhere((b) => b.id == id);
    if (idx >= 0) _budgets[idx] = _budgets[idx].copyWith(isDeleted: true);
    notifyListeners();
  }

  Future<void> addGoal(Goal g) async {
    _goals.add(g);
    notifyListeners();
  }

  Future<void> updateGoal(String id, {double? currentAmount}) async {
    final idx = _goals.indexWhere((g) => g.id == id);
    if (idx >= 0) _goals[idx] = _goals[idx].copyWith(currentAmount: currentAmount);
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }
}
