import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart' as cat;
import '../models/goal.dart';
import '../models/operation.dart';
import '../models/recommendation.dart';
import '../models/tag.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';

class FinanceStore extends ChangeNotifier {
  final AuthService authService;
  final ApiClient apiClient;
  User? _currentUser;
  List<Account> _accounts = [];
  List<Operation> _operations = [];
  List<cat.Category> _categories = [];
  List<Budget> _budgets = [];
  List<Goal> _goals = [...mockGoals];
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

  void saveUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    await authService.logout();
    _currentUser = null;
    _accounts = [];
    _operations = [];
    _categories = [];
    _budgets = [];
    _tags = [];
    _goals = [...mockGoals];
    _recommendations = [...mockRecommendations];
    _useMock = true;
    _loadFromMock();
  }

  bool get isAuthenticated => authService.isAuthenticated;
  User? get currentUser => _currentUser;
  List<Account> get accounts => _accounts;
  List<Operation> get operations => _operations.where((o) => !o.isDeleted).toList();
  List<cat.Category> get categories => _categories;
  List<Budget> get budgets => _budgets.where((b) => !b.isDeleted).toList();
  List<Goal> get goals => _goals;
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

    await _loadBudgets();

    final api = authService.apiService;

    try {
      final user = await api.getUser();
      _currentUser = user;
      if (user.id.isNotEmpty && apiClient.userId != user.id) {
        apiClient.setAuth(
          accessToken: apiClient.accessToken ?? '',
          userId: user.id,
        );
      }
    } on ApiException catch (_) {}

    try {
      _accounts = await api.getAccounts();
    } on ApiException catch (e) {
      _error = e.message;
    }

    try {
      _operations = await api.getOperations();
    } on ApiException catch (e) {
      _error = e.message;
    }

    try {
      _categories = await api.getCategories();
    } on ApiException catch (e) {
      _error = e.message;
    }

    try {
      _tags = await api.getTags();
    } on ApiException catch (e) {
      _error = e.message;
    }

    try {
      final patterns = await api.getOperationPatterns();
      final goals = patterns.where((p) => p['type']?.toString() == '4').toList();
      final balanceMap = <String, double>{};
      for (final a in _accounts) {
        balanceMap[a.id] = a.balance;
      }
      _goals = goals.map((g) => Goal.fromJson(g, accountBalances: balanceMap)).toList();
    } on ApiException catch (_) {}

    for (var i = 0; i < _budgets.length; i++) {
      final b = _budgets[i];
      final ops = _operations.where((o) =>
        o.categoryId == b.categoryId && o.type == 'expense');
      final total = ops.fold(0.0, (sum, o) => sum + o.amount);
      _budgets[i] = b.copyWith(spent: total);
    }
    await _saveBudgets();

    _useMock = _accounts.isEmpty && _operations.isEmpty && _categories.isEmpty && _tags.isEmpty;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addOperation(Operation op) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final now = DateTime.now();
        final dateStr = now.toIso8601String();
        final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        final amount = op.type == 'income' ? op.amount : -op.amount;
        final clientId = int.tryParse(op.id) ?? op.id.hashCode;

        await authService.apiService.addOperation({
          'operations': [{
            'type': _typeToApi(op.type),
            'user_id': apiClient.userId ?? '',
            'account_id': op.accountId,
            if (op.categoryId != null) 'category_id': op.categoryId,
            'amount': amount.toStringAsFixed(2),
            'date': dateStr,
            'time': timeStr,
            'transfer_account_id': op.toAccountId,
            'transfer_amount': op.toAccountId != null ? op.amount.toStringAsFixed(2) : null,
            if (op.comment != null) 'comment': op.comment,
            'accepted': true,
            'client_id': clientId,
            'created_at': dateStr,
            'updated_at': dateStr,
            'deleted_at': null,
          }]
        });
      } catch (_) {}
    }
    _operations.insert(0, op);
    _updateBalancesOnAdd(op);
    notifyListeners();
  }

  String _typeToApi(String type) {
    switch (type) {
      case 'expense': return '0';
      case 'income': return '1';
      case 'transfer': return '2';
      default: return '0';
    }
  }

  Future<void> updateOperation(Operation op) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final now = DateTime.now();
        final dateStr = now.toIso8601String();
        final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        final amount = op.type == 'income' ? op.amount : -op.amount;

        await authService.apiService.setOperation({
          'operations': [{
            'id': op.id,
            'type': _typeToApi(op.type),
            'account_id': op.accountId,
            if (op.categoryId != null) 'category_id': op.categoryId,
            'amount': amount.toStringAsFixed(2),
            'date': dateStr,
            'time': timeStr,
            'transfer_account_id': op.toAccountId,
            'transfer_amount': op.toAccountId != null ? op.amount.toStringAsFixed(2) : null,
            if (op.comment != null) 'comment': op.comment,
            'accepted': true,
            'updated_at': dateStr,
            'deleted_at': null,
          }]
        });
      } catch (_) {}
    }
    final idx = _operations.indexWhere((o) => o.id == op.id);
    if (idx >= 0) {
      _updateBalancesOnDelete(_operations[idx]);
      _operations[idx] = op;
      _updateBalancesOnAdd(op);
    }
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

  Future<void> addAccount(Account account) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        await authService.apiService.addAccount({
          'accounts': [{
            'name': account.name,
            'balance': account.balance.abs().toString(),
            'type_id': _accountTypeToApi(account.type),
            'currency_id': '1',
            'icon': _accountIconToApi(account.icon),
          }]
        }, options: 'client');
      } catch (_) {}
    }
    _accounts.add(account);
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        await authService.apiService.setAccount({
          'accounts': [{
            'id': account.id,
            'name': account.name,
            'balance': account.balance.abs().toString(),
            'type_id': _accountTypeToApi(account.type),
            'icon': _accountIconToApi(account.icon),
          }]
        });
      } catch (_) {}
    }
    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) _accounts[idx] = account;
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        await authService.apiService.setAccount({
          'accounts': [{
            'id': id,
            'deleted_at': DateTime.now().toIso8601String(),
          }]
        });
      } catch (_) {}
    }
    _accounts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  String _accountTypeToApi(String type) {
    switch (type) {
      case 'card': return '2';
      case 'credit': return '8';
      case 'savings': return '5';
      default: return '1';
    }
  }

  String _accountIconToApi(String icon) {
    const map = <String, String>{
      'cash': 'accountimage1', 'credit_card': 'accountimage2',
      'savings': 'accountimage3', 'account_balance': 'accountimage4',
      'wallet': 'accountimage5', 'payments': 'accountimage6',
      'currency_ruble': 'accountimage7', 'card_giftcard': 'accountimage8',
    };
    return map[icon] ?? 'accountimage1';
  }

  Future<void> addBudget(Budget b) async {
    _budgets.add(b);
    await _saveBudgets();
    notifyListeners();
  }

  Future<void> deleteBudget(String id) async {
    final idx = _budgets.indexWhere((b) => b.id == id);
    if (idx >= 0) _budgets[idx] = _budgets[idx].copyWith(isDeleted: true);
    await _saveBudgets();
    notifyListeners();
  }

  Future<void> _saveBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _budgets.map((b) => {
      'id': b.id,
      'name': b.name,
      'categoryId': b.categoryId,
      'limit': b.limit,
      'spent': b.spent,
      'period': b.period,
      'isDeleted': b.isDeleted,
    }).toList();
    await prefs.setString('easyfinance_budgets', jsonEncode(data));
  }

  Future<void> _loadBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('easyfinance_budgets');
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _budgets = list.map((e) {
        final m = e as Map<String, dynamic>;
        return Budget(
          id: m['id'] as String,
          name: m['name'] as String?,
          categoryId: m['categoryId'] as String? ?? '',
          limit: (m['limit'] as num).toDouble(),
          spent: (m['spent'] as num?)?.toDouble() ?? 0,
          period: m['period'] as String? ?? 'monthly',
          isDeleted: m['isDeleted'] as bool? ?? false,
        );
      }).toList();
    }
  }

  Future<void> addCategory(cat.Category category) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        await authService.apiService.setCategory({
          'categories': [{
            'name': category.name,
            'type': category.type == 'income' ? '1' : '-1',
            'custom': '1',
          }]
        });
      } catch (_) {}
    }
    _categories.add(category);
    notifyListeners();
  }

  Future<void> updateCategory(cat.Category category) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        await authService.apiService.setCategory({
          'categories': [{
            'id': category.id,
            'name': category.name,
            'type': category.type == 'income' ? '1' : '-1',
          }]
        });
      } catch (_) {}
    }
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx >= 0) _categories[idx] = category;
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> addGoal(Goal g) async {
    _goals.add(g);
    notifyListeners();
  }

  Future<void> updateGoal(String id, {double? currentAmount, bool? isCompleted}) async {
    final idx = _goals.indexWhere((g) => g.id == id);
    if (idx >= 0) {
      _goals[idx] = _goals[idx].copyWith(currentAmount: currentAmount, isCompleted: isCompleted);
    }
    notifyListeners();
  }

  Future<void> depositToGoal(String goalId, double amount, String accountId) async {
    final goal = _goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null || amount <= 0) return;

    final newAmount = goal.currentAmount + amount;
    final completed = newAmount >= goal.targetAmount;

    updateGoal(goalId, currentAmount: newAmount, isCompleted: completed);

    addOperation(Operation(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      type: 'expense',
      amount: amount,
      date: DateTime.now().toIso8601String(),
      accountId: accountId,
      categoryId: _categories.where((c) => c.name == 'Накопления' || c.name == 'Переводы').firstOrNull?.id,
      comment: 'Пополнение цели: ${goal.title}',
    ));
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }
}
