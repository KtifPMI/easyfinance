import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart' as cat;
import '../models/goal.dart';
import '../models/operation.dart';
import '../models/operation_template.dart';
import '../models/recommendation.dart';
import '../models/tag.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/mock_data.dart' show mockAccounts, mockOperations, mockBudgets, mockCategories;
import '../utils/format.dart';

class FinanceStore extends ChangeNotifier {
  final AuthService authService;
  final ApiClient apiClient;
  User? _currentUser;
  List<Account> _accounts = [];
  List<Operation> _operations = [];
  List<cat.Category> _categories = [];
  List<Budget> _budgets = [];
  List<Goal> _goals = [];
  List<Recommendation> _recommendations = [];
  List<Tag> _tags = [];
  List<OperationTemplate> _templates = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _systemCategories = [];
  BudgetInfo? _serverBudget;
  bool _isLoading = false;
  bool _useMock = true;
  String? _error;

  FinanceStore({required this.authService, required this.apiClient}) {
    _loadFromCache();
    _loadTemplates();
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsRaw = prefs.getString('easyfinance_cached_accounts');
    final operationsRaw = prefs.getString('easyfinance_cached_operations');
    final categoriesRaw = prefs.getString('easyfinance_cached_categories');
    final tagsRaw = prefs.getString('easyfinance_cached_tags');
    final userRaw = prefs.getString('easyfinance_cached_user');
    if (accountsRaw != null) {
      final list = jsonDecode(accountsRaw) as List<dynamic>;
      _accounts = list.map((e) => Account.fromLocalJson(e as Map<String, dynamic>)).toList();
      _useMock = false;
    }
    if (operationsRaw != null) {
      final list = jsonDecode(operationsRaw) as List<dynamic>;
      _operations = list.map((e) => Operation.fromLocalJson(e as Map<String, dynamic>)).toList();
      _useMock = false;
    }
    if (categoriesRaw != null) {
      final list = jsonDecode(categoriesRaw) as List<dynamic>;
      _categories = list.map((e) => cat.Category.fromLocalJson(e as Map<String, dynamic>)).toList();
      _useMock = false;
    }
    if (tagsRaw != null) {
      final list = jsonDecode(tagsRaw) as List<dynamic>;
      _tags = list.map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (userRaw != null) {
      try { _currentUser = User.fromJson(jsonDecode(userRaw) as Map<String, dynamic>); } catch (_) {}
    }
    _generateRecommendations();
    notifyListeners();
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accounts.isNotEmpty) {
      await prefs.setString('easyfinance_cached_accounts', jsonEncode(_accounts.map((a) => a.toJson()).toList()));
    }
    if (_operations.isNotEmpty) {
      await prefs.setString('easyfinance_cached_operations', jsonEncode(_operations.map((o) => o.toJson()).toList()));
    }
    if (_categories.isNotEmpty) {
      await prefs.setString('easyfinance_cached_categories', jsonEncode(_categories.map((c) => c.toJson()).toList()));
    }
    if (_tags.isNotEmpty) {
      await prefs.setString('easyfinance_cached_tags', jsonEncode(_tags.map((t) => t.toJson()).toList()));
    }
    if (_currentUser != null) {
      await prefs.setString('easyfinance_cached_user', jsonEncode(_currentUser!.toJson()));
    }
  }

  void saveUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('easyfinance_budgets');
    await prefs.remove('easyfinance_goals');
    await prefs.remove('easyfinance_planned_payments');
    await prefs.remove('easyfinance_templates');
    await prefs.remove('easyfinance_cached_accounts');
    await prefs.remove('easyfinance_cached_operations');
    await prefs.remove('easyfinance_cached_categories');
    await prefs.remove('easyfinance_cached_tags');
    await prefs.remove('easyfinance_cached_user');
    await authService.logout();
    _currentUser = null;
    _accounts = [];
    _operations = [];
    _categories = [];
    _budgets = [];
    _goals = [];
    _tags = [];
    _templates = [];
    _useMock = true;
    notifyListeners();
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
  List<OperationTemplate> get templates => _templates;
  List<Map<String, dynamic>> get currencies => _currencies;
  List<Map<String, dynamic>> get systemCategories => _systemCategories;
  BudgetInfo? get serverBudget => _serverBudget;
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

  bool isInCurrentMonth(String dateIso) => isInMonth(dateIso, DateTime.now());

  bool isInMonth(String dateIso, DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    return _inPeriod(dateIso, start, end);
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
    await _loadGoals();

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
      if (_categories.isEmpty) {
        _categories = [...mockCategories];
      }
    } on ApiException catch (e) {
      _error = e.message;
    }

    try {
      _tags = await api.getTags();
    } on ApiException catch (_) {}

    try {
      final apiTemplates = await api.getTemplates();
      final localIds = _templates.map((t) => t.id).toSet();
      for (final t in apiTemplates) {
        if (!localIds.contains(t.id)) _templates.add(t);
      }
      await _saveTemplates();
    } on ApiException catch (_) {}
    notifyListeners();

    try {
      _serverBudget = await api.getBudget();
    } on ApiException catch (_) {}

    try {
      _currencies = await api.getCurrencies();
    } on ApiException catch (_) {}

    try {
      _systemCategories = await api.getSystemCategories();
    } on ApiException catch (_) {}

    try {
      final goals = await api.getGoals();
      for (final g in goals.map((g) => Goal.fromJson(g))) {
        final idx = _goals.indexWhere((e) => e.id == g.id);
        if (idx >= 0) {
          _goals[idx] = g;
        } else {
          _goals.add(g);
        }
      }
    } on ApiException catch (_) {}

    _recalcAccountBalances();

    for (var i = 0; i < _budgets.length; i++) {
      final b = _budgets[i];
      final spent = _calcSpentForMonth(b.categoryId);
      _budgets[i] = b.copyWith(spent: spent);
    }
    await _saveBudgets();

    _generateRecommendations();

    _useMock = _accounts.isEmpty && _operations.isEmpty && _categories.isEmpty;
    _isLoading = false;
    await _saveCache();
    notifyListeners();
  }

  void _generateRecommendations() {
    _recommendations = [];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    bool inRange(Operation o) {
      final d = DateTime.tryParse(o.date);
      return d != null && !d.isBefore(monthStart) && !d.isAfter(monthEnd);
    }

    final monthIncome = _operations.where((o) => o.type == 'income' && inRange(o)).fold(0.0, (s, o) => s + o.amount);
    final monthExpense = _operations.where((o) => o.type == 'expense' && inRange(o)).fold(0.0, (s, o) => s + o.amount);

    // 1 — budget overspent or near limit
    for (final b in _budgets.where((b) => !b.isDeleted)) {
      final cat = _categories.where((c) => c.id == b.categoryId).firstOrNull;
      final name = cat?.name ?? b.name ?? '';
      if (b.spent > b.limit) {
        _recommendations.add(Recommendation(
          id: 'b_overspent_${b.id}', type: 'risk', severity: 'high',
          title: 'Лимит превышен: $name',
          description: 'Потрачено ${b.spent.toStringAsFixed(0)} ₽ при лимите ${b.limit.toStringAsFixed(0)} ₽ (превышение ${(b.spent - b.limit).toStringAsFixed(0)} ₽, ${(b.spent / b.limit * 100).round()}% от лимита).',
        ));
      } else if (b.spent > b.limit * 0.8) {
        final remaining = b.limit - b.spent;
        _recommendations.add(Recommendation(
          id: 'b_near_${b.id}', type: 'optimization', severity: 'medium',
          title: 'Близок к лимиту: $name',
          description: 'Использовано ${b.spent.toStringAsFixed(0)} ₽ из ${b.limit.toStringAsFixed(0)} ₽ (${(b.spent / b.limit * 100).round()}%). Осталось всего ${remaining.toStringAsFixed(0)} ₽ до конца месяца.',
        ));
      }
    }

    // 2 — total food (groceries + dining) as income percentage
    final foodCats = _categories.where((c) =>
      c.name.contains('продукт') || c.name.contains('кафе') || c.name.contains('ресторан') ||
      c.name.contains('food') || c.name.contains('cafe') || c.name.contains('restaurant') || c.name.contains('еда')
    ).map((c) => c.id).toSet();
    if (foodCats.isNotEmpty && monthIncome > 0) {
      double foodTotal = 0;
      double diningTotal = 0;
      int diningCount = 0;
      for (final o in _operations.where((o) => o.type == 'expense' && inRange(o) && foodCats.contains(o.categoryId))) {
        final cat = _categories.where((c) => c.id == o.categoryId).firstOrNull;
        if (cat != null && (cat.name.contains('кафе') || cat.name.contains('ресторан') || cat.name.contains('cafe') || cat.name.contains('restaurant'))) {
          diningTotal += o.amount;
          diningCount++;
        } else {
          foodTotal += o.amount;
        }
      }
      final allFood = foodTotal + diningTotal;
      if (allFood > 0) {
        final foodRatio = allFood / monthIncome * 100;
        if (foodRatio > 50) {
          _recommendations.add(Recommendation(
            id: 'high_food', type: 'risk', severity: 'high',
            title: 'Высокие расходы на питание',
            description: 'На питание уходит ${foodRatio.round()}% дохода (${allFood.toStringAsFixed(0)} ₽ из ${monthIncome.toStringAsFixed(0)} ₽). Рекомендуется не более 30%.',
          ));
        } else if (foodRatio > 30) {
          _recommendations.add(Recommendation(
            id: 'food_warning', type: 'optimization', severity: 'medium',
            title: 'Питание отнимает ${foodRatio.round()}% дохода',
            description: 'Потрачено ${allFood.toStringAsFixed(0)} ₽ из ${monthIncome.toStringAsFixed(0)} ₽. Постарайтесь уложиться в 30%.',
          ));
        }
      }
      if (diningCount >= 5 && diningTotal > 0) {
        _recommendations.add(Recommendation(
          id: 'dining_freq', type: 'optimization', severity: 'low',
          title: '$diningCount раз(а) в кафе за месяц',
          description: 'На кафе и рестораны ушло ${diningTotal.toStringAsFixed(0)} ₽ (${(diningTotal / monthIncome * 100).round()}% дохода). Домашняя еда поможет сэкономить.',
        ));
      }
    }

    // 3 — no budget for high-spend categories
    final topSpend = <String, double>{};
    for (final o in _operations.where((o) => o.type == 'expense' && o.categoryId != null)) {
      topSpend.update(o.categoryId!, (v) => v + o.amount, ifAbsent: () => o.amount);
    }
    final budgetedCats = _budgets.where((b) => !b.isDeleted).map((b) => b.categoryId).toSet();
    final sortedCats = topSpend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedCats.take(3)) {
      if (!budgetedCats.contains(entry.key)) {
        final cat = _categories.where((c) => c.id == entry.key).firstOrNull;
        if (cat != null && entry.value > 1000) {
          final pct = monthExpense > 0 ? (entry.value / monthExpense * 100).round() : 0;
          _recommendations.add(Recommendation(
            id: 'no_budget_${entry.key}', type: 'optimization', severity: 'medium',
            title: 'Нет бюджета для «${cat.name}»',
            description: 'Потрачено ${entry.value.toStringAsFixed(0)} ₽ ($pct% от всех расходов). Установите бюджет, чтобы контролировать эту категорию.',
          ));
        }
      }
    }

    // 4 — fixed costs (housing) vs income
    final housingCats = _categories.where((c) =>
      c.name.contains('жиль') || c.name.contains('аренд') || c.name.contains('квартир') || c.name.contains('коммунал') ||
      c.name.contains('rent') || c.name.contains('housing') || c.name.contains('utility') || c.name.contains('mortgage')
    ).map((c) => c.id).toSet();
    double housingTotal = 0;
    for (final o in _operations.where((o) => o.type == 'expense' && inRange(o) && housingCats.contains(o.categoryId))) {
      housingTotal += o.amount;
    }
    if (monthIncome > 0 && housingTotal > 0) {
      final housingRatio = housingTotal / monthIncome * 100;
      if (housingRatio > 30) {
        _recommendations.add(Recommendation(
          id: 'high_housing', type: 'risk', severity: 'high',
          title: 'Жильё — ${housingRatio.round()}% от дохода',
          description: 'На жильё уходит ${housingTotal.toStringAsFixed(0)} ₽ из ${monthIncome.toStringAsFixed(0)} ₽ (${housingRatio.round()}%). Рекомендуется не более 30%.',
        ));
      }
    }

    // 5 — savings rate
    if (monthIncome > 0) {
      final savingsRate = (monthIncome - monthExpense) / monthIncome * 100;
      if (savingsRate < 0) {
        _recommendations.add(Recommendation(
          id: 'negative_savings', type: 'risk', severity: 'high',
          title: 'Расходы превышают доходы',
          description: 'Доход ${monthIncome.toStringAsFixed(0)} ₽, расходы ${monthExpense.toStringAsFixed(0)} ₽ (дефицит ${(monthExpense - monthIncome).toStringAsFixed(0)} ₽). Пересмотрите бюджет.',
        ));
      } else if (savingsRate < 10) {
        final saveAmt = monthIncome - monthExpense;
        _recommendations.add(Recommendation(
          id: 'low_savings', type: 'risk', severity: 'medium',
          title: 'Низкая норма сбережения',
          description: 'Откладывается ${saveAmt.toStringAsFixed(0)} ₽ (${savingsRate.round()}% от ${monthIncome.toStringAsFixed(0)} ₽). Цель — минимум 20% (${(monthIncome * 0.2).toStringAsFixed(0)} ₽).',
        ));
      } else if (savingsRate >= 20) {
        final saveAmt = monthIncome - monthExpense;
        _recommendations.add(Recommendation(
          id: 'good_savings', type: 'tip', severity: 'low',
          title: 'Хорошая норма сбережения',
          description: 'Отложено ${saveAmt.toStringAsFixed(0)} ₽ (${savingsRate.round()}% от ${monthIncome.toStringAsFixed(0)} ₽). Отличный результат!',
        ));
      }
    }

    // 6 — biggest expense categories
    if (monthExpense > 0) {
      final topCatList = sortedCats.take(5).where((e) {
        final cat = _categories.where((c) => c.id == e.key).firstOrNull;
        return cat != null && e.value > monthExpense * 0.15;
      }).toList();
      if (topCatList.length >= 2) {
        final parts = topCatList.map((e) {
          final cat = _categories.where((c) => c.id == e.key).firstOrNull;
          final pct = (e.value / monthExpense * 100).round();
          return '${cat?.name ?? e.key} ${e.value.toStringAsFixed(0)} ₽ ($pct%)';
        }).join(', ');
        _recommendations.add(Recommendation(
          id: 'top_cats', type: 'tip', severity: 'low',
          title: 'Структура расходов',
          description: 'Основные статьи: $parts.',
        ));
      }
    }

    // 7 — no emergency fund goal
    if (_goals.where((g) =>
      !g.isCompleted && (g.title.contains('подушк') || g.title.contains('безопасн') || g.title.contains('сбережен') ||
                         g.title.contains('emergency') || g.title.contains('safety') || g.title.contains('cushion'))
    ).isEmpty) {
      final suggested = monthExpense > 0 ? (monthExpense * 3).toStringAsFixed(0) : '—';
      _recommendations.add(Recommendation(
        id: 'no_emergency', type: 'tip', severity: 'low',
        title: 'Создайте финансовую подушку',
        description: 'Рекомендуется резерв 3–6 месячных расходов ($suggested ₽). Добавьте цель «Подушка безопасности» в разделе целей.',
      ));
    }

    // 8 — idle cash
    for (final a in _accounts) {
      if (a.icon == 'cash' && a.balance > 50000) {
        _recommendations.add(Recommendation(
          id: 'idle_cash_${a.id}', type: 'optimization', severity: 'low',
          title: '${a.balance.toStringAsFixed(0)} ₽ наличными без движения',
          description: 'На счету «${a.name}» ${a.balance.toStringAsFixed(0)} ₽. Часть можно перенести на накопительный счёт или вклад.',
        ));
      }
    }

    // 9 — goal progress
    for (final g in _goals.where((g) => !g.isCompleted && g.targetAmount > 0)) {
      final progress = g.currentAmount / g.targetAmount * 100;
      if (progress >= 75) {
        _recommendations.add(Recommendation(
          id: 'goal_close_${g.id}', type: 'tip', severity: 'low',
          title: 'Цель «${g.title}» почти достигнута',
          description: 'Накоплено ${g.currentAmount.toStringAsFixed(0)} ₽ из ${g.targetAmount.toStringAsFixed(0)} ₽ (${progress.round()}%). Осталось ${(g.targetAmount - g.currentAmount).toStringAsFixed(0)} ₽.',
        ));
      }
    }

    // fallback: if nothing generated, add a friendly tip
    if (_recommendations.isEmpty) {
      _recommendations.add(Recommendation(
        id: 'all_good', type: 'tip', severity: 'low',
        title: 'Всё в порядке!',
        description: 'Сейчас нет рекомендаций. Добавляйте операции и ставьте цели — советы появятся автоматически.',
      ));
    }
  }

  Future<void> addOperation(Operation op) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final now = DateTime.now();
        final tz = now.timeZoneOffset;
        final tzStr = '${tz.isNegative ? '-' : '+'}${tz.inHours.abs().toString().padLeft(2, '0')}:${(tz.inMinutes % 60).abs().toString().padLeft(2, '0')}';
        final isoStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}$tzStr';
        final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        final amount = op.type == 'income' ? op.amount : -op.amount;
        final clientId = int.parse('${(now.microsecondsSinceEpoch % 1000000).abs()}');

        await authService.apiService.addOperation({
          'operations': [{
            'type': _typeToApi(op.type),
            'user_id': apiClient.userId ?? '',
            'account_id': op.accountId,
            if (op.categoryId != null) 'category_id': op.categoryId,
            'amount': amount.toStringAsFixed(2),
            'date': isoStr,
            'time': timeStr,
            if (op.toAccountId != null) 'to_account_id': op.toAccountId,
            if (op.toAccountId != null) 'transfer_amount': op.amount.toStringAsFixed(2),
            if (op.comment != null) 'comment': op.comment,
            if (op.tags != null) 'tags': op.tags,
            'accepted': true,
            'client_id': clientId,
            'created_at': isoStr,
            'updated_at': isoStr,
            'deleted_at': null,
          }]
        });
      } on ApiException catch (e) {
        _error = e.message;
        notifyListeners();
      } catch (e) {
        _error = 'Ошибка добавления: $e';
        notifyListeners();
      }
    }
    _operations.insert(0, op);
    _recalcAccountBalances();
    _generateRecommendations();
    await _saveCache();
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
        final dateStr = formatApiDateTime(now);
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
            'to_account_id': op.toAccountId,
            'transfer_amount': op.toAccountId != null ? op.amount.toStringAsFixed(2) : null,
            if (op.comment != null) 'comment': op.comment,
            if (op.tags != null) 'tags': op.tags,
            'accepted': true,
            'updated_at': dateStr,
            'deleted_at': null,
          }]
        });
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка обновления: $e'; notifyListeners();
      }
    }
    final idx = _operations.indexWhere((o) => o.id == op.id);
    if (idx >= 0) {
      _operations[idx] = op;
    }
    _recalcAccountBalances();
    _generateRecommendations();
    await _saveCache();
    notifyListeners();
  }

  Future<void> deleteOperation(String id) async {
    final op = _operations.firstWhere((o) => o.id == id);
    if (!_useMock && authService.isAuthenticated) {
      try {
        await authService.apiService.setOperation({
          'operations': [{
            'id': op.id,
            'state': '2',
            'deleted_at': formatApiDateTime(),
          }]
        });
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка удаления: $e'; notifyListeners();
      }
    }
    if (!op.isDeleted) {
      final idx = _operations.indexWhere((o) => o.id == id);
      _operations[idx] = _operations[idx].copyWith(isDeleted: true);
    }
    _recalcAccountBalances();
    _generateRecommendations();
    await _saveCache();
    notifyListeners();
  }

  Future<void> refundOperation(Operation op) async {
    final refundOp = Operation(
      id: '',
      type: 'income',
      amount: op.amount,
      currency: op.currency,
      date: DateTime.now().toIso8601String().substring(0, 10),
      accountId: op.accountId,
      toAccountId: null,
      categoryId: op.categoryId,
      comment: 'Возврат: ${op.comment ?? ''}'.trimRight(),
      isDeleted: false,
    );
    await addOperation(refundOp);
  }

  Future<void> addAccount(Account account) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        final newAccount = account.copyWith();
        final resp = await authService.apiService.addAccount({
          'accounts': [{
            'name': account.name,
            'init_balance': (account.initBalance > 0 ? account.initBalance : account.balance).toStringAsFixed(2),
            'type_id': _accountTypeToApi(account.type),
            'state': '0',
            if (account.currencyId != null) 'currency_id': account.currencyId else 'currency_id': '1',
            'icon': _accountIconToApi(account.icon),
            'created_at': account.createdAt.isNotEmpty ? account.createdAt : now,
            'updated_at': now,
          }]
        });
        final accounts = resp['accounts'] as List<dynamic>?;
        if (accounts != null && accounts.isNotEmpty) {
          final serverId = accounts[0]['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            _accounts.add(newAccount.copyWith(id: serverId));
            await _saveCache();
            notifyListeners();
            return;
          }
        }
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка добавления счёта: $e'; notifyListeners();
      }
    }
    _accounts.add(account);
    await _saveCache();
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        await authService.apiService.setAccount({
          'accounts': [{
            'id': account.id,
            'name': account.name,
            'init_balance': account.initBalance.toStringAsFixed(2),
            'type_id': _accountTypeToApi(account.type),
            'state': '0',
            if (account.currencyId != null) 'currency_id': account.currencyId else 'currency_id': '1',
            'icon': _accountIconToApi(account.icon),
            'updated_at': now,
          }]
        }, accountId: account.id);
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка обновления счёта: $e'; notifyListeners();
      }
    }
    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) _accounts[idx] = account;
    _recalcAccountBalances();
    await _saveCache();
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final account = _accounts.firstWhere((a) => a.id == id);
        final now = formatApiDateTime();
        await authService.apiService.setAccount({
          'accounts': [{
            'id': id,
            'name': account.name,
            'init_balance': account.initBalance.toStringAsFixed(2),
            'type_id': _accountTypeToApi(account.type),
            if (account.currencyId != null) 'currency_id': account.currencyId else 'currency_id': '1',
            'icon': _accountIconToApi(account.icon),
            'state': '2',
            'updated_at': now,
            'deleted_at': now,
          }]
        }, accountId: id);
      } on StateError {
        final now = formatApiDateTime();
        await authService.apiService.setAccount({
          'accounts': [{
            'id': id,
            'name': 'Deleted Account',
            'init_balance': '0.00',
            'type_id': '1',
            'currency_id': '1',
            'icon': 'accountimage1',
            'state': '2',
            'updated_at': now,
            'deleted_at': now,
          }]
        }, accountId: id);
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка удаления счёта: $e'; notifyListeners();
      }
    }
    _accounts.removeWhere((a) => a.id == id);
    await _saveCache();
    notifyListeners();
  }

  // --- Categories ---

  Future<void> addCategory(cat.Category c) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        final typeCode = c.type == 'expense' ? '-1' : '1';
        final resp = await authService.apiService.addCategory({
          'categories': [{
            'name': c.name,
            'type': typeCode,
            'icon': _categoryIconToApi(c.icon),
            if (c.parentId != null) 'parent_id': c.parentId,
            'created_at': now,
            'updated_at': now,
          }]
        }, options: 'client');
        final categories = resp['categories'] as List<dynamic>?;
        if (categories != null && categories.isNotEmpty) {
          final serverId = categories[0]['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            _categories.add(cat.Category(
              id: serverId, name: c.name, type: c.type, icon: c.icon, parentId: c.parentId, isDefault: false,
            ));
            await _saveCache();
            notifyListeners();
            return;
          }
        }
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка добавления категории: $e'; notifyListeners();
      }
    }
    _categories.add(c);
    await _saveCache();
    notifyListeners();
  }

  Future<void> updateCategory(cat.Category c) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        final typeCode = c.type == 'expense' ? '-1' : '1';
        await authService.apiService.setCategory({
          'categories': [{
            'id': c.id,
            'name': c.name,
            'type': typeCode,
            'icon': _categoryIconToApi(c.icon),
            'parent_id': c.parentId,
            'updated_at': now,
          }]
        }, categoryId: c.id);
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка обновления категории: $e'; notifyListeners();
      }
    }
    final idx = _categories.indexWhere((x) => x.id == c.id);
    if (idx >= 0) _categories[idx] = c;
    await _saveCache();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        await authService.apiService.setCategory({
          'categories': [{'id': id, 'deleted_at': now}]
        }, categoryId: id);
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка удаления категории: $e'; notifyListeners();
      }
    }
    _categories.removeWhere((x) => x.id == id);
    await _saveCache();
    notifyListeners();
  }

  String _categoryIconToApi(String icon) {
    const map = <String, String>{
      'food': 'catimg1', 'transport': 'catimg2', 'housing': 'catimg3', 'shopping': 'catimg4',
      'health': 'catimg5', 'entertainment': 'catimg6', 'education': 'catimg7', 'travel': 'catimg8',
      'salary': 'catimg9', 'freelance': 'catimg10', 'business': 'catimg11', 'gift': 'catimg12',
      'car': 'catimg13', 'sports': 'catimg14', 'dining': 'catimg15', 'utilities': 'catimg16',
      'internet': 'catimg17', 'clothing': 'catimg18', 'children': 'catimg19', 'pets': 'catimg20',
      'taxes': 'catimg21', 'insurance': 'catimg22', 'invest': 'catimg23', 'rent': 'catimg24',
      'other_income': 'catimg25', 'other_expense': 'catimg26',
    };
    return map[icon] ?? 'catimg26';
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
    final spent = _calcSpentForMonth(b.categoryId);
    _budgets.add(b.copyWith(spent: spent));
    await _saveBudgets();
    notifyListeners();
  }

  double _calcSpentForMonth(String categoryId) {
    final now = DateTime.now();
    final ops = _operations.where((o) {
      if (o.categoryId != categoryId || o.type != 'expense' || o.isDeleted) return false;
      final d = DateTime.tryParse(o.date.substring(0, 10));
      return d != null && d.year == now.year && d.month == now.month;
    });
    return ops.fold(0.0, (sum, o) => sum + o.amount);
  }

  void _recalcAccountBalances() {
    for (var i = 0; i < _accounts.length; i++) {
      final a = _accounts[i];
      double balance = a.initBalance;
      for (final op in _operations.where((o) => !o.isDeleted)) {
        if (op.type == 'expense' && op.accountId == a.id) {
          balance -= op.amount;
        } else if (op.type == 'income' && op.accountId == a.id) {
          balance += op.amount;
        } else if (op.type == 'transfer') {
          if (op.accountId == a.id) balance -= op.amount;
          if (op.toAccountId == a.id) balance += op.amount;
        }
      }
      if ((balance - a.balance).abs() > 0.01) {
        _accounts[i] = a.copyWith(balance: balance);
      }
    }
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

  Future<void> addGoal(Goal g) async {
    _goals.add(g);
    await _saveGoals();
    notifyListeners();
  }

  Future<void> updateGoal(String id, {double? currentAmount, bool? isCompleted}) async {
    final idx = _goals.indexWhere((g) => g.id == id);
    if (idx >= 0) {
      _goals[idx] = _goals[idx].copyWith(currentAmount: currentAmount, isCompleted: isCompleted);
    }
    await _saveGoals();
    notifyListeners();
  }

  Future<void> depositToGoal(String goalId, double amount, String accountId) async {
    final goal = _goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null || amount <= 0) return;

    final newAmount = goal.currentAmount + amount;
    final completed = newAmount >= goal.targetAmount;

    updateGoal(goalId, currentAmount: newAmount, isCompleted: completed);

    final goalCategoryId = _categories
        .where((c) =>
            c.name == 'Инвестиционный расход' ||
            c.name.contains('Инвестицион'))
        .firstOrNull
        ?.id;
    final categoryId = goalCategoryId ??
        _categories
            .where((c) => c.name == 'Прочие расходы')
            .firstOrNull
            ?.id;

    addOperation(Operation(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      type: 'expense',
      amount: amount,
      date: DateTime.now().toIso8601String(),
      accountId: accountId,
      categoryId: categoryId,
      comment: '🎯 ${goal.title}',
    ));
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    await _saveGoals();
    notifyListeners();
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _goals.map((g) => g.toJson()).toList();
    await prefs.setString('easyfinance_goals', jsonEncode(data));
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('easyfinance_goals');
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _goals = list.map((e) => Goal.fromLocalJson(e as Map<String, dynamic>)).toList();
    }
  }

  // --- Templates ---

  Future<void> addTemplate(OperationTemplate t) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        final typeCode = t.type == 'expense' ? 0 : t.type == 'income' ? 1 : 2;
        final clientId = DateTime.now().millisecondsSinceEpoch.toString();
        final userId = authService.userId ?? '';
        final resp = await authService.apiService.addTemplate({
          'operationPatterns': [{
            'client_id': clientId,
            'user_id': userId,
            'name': t.name,
            'type': typeCode,
            'amount': t.amount.toStringAsFixed(2),
            if (t.accountId != null) 'account_id': t.accountId,
            if (t.categoryId != null) 'category_id': t.categoryId,
            if (t.toAccountId != null) 'to_account_id': t.toAccountId,
            if (t.comment != null) 'comment': t.comment,
            if (t.tags != null) 'tags': t.tags,
            'created_at': now,
            'updated_at': now,
          }]
        }, options: 'client');
        final patterns = resp['operationPatterns'] as List<dynamic>?;
        if (patterns != null && patterns.isNotEmpty) {
          final serverId = patterns[0]['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            _templates.add(OperationTemplate(
              id: serverId, name: t.name, type: t.type, amount: t.amount,
              accountId: t.accountId, categoryId: t.categoryId, toAccountId: t.toAccountId,
              comment: t.comment, tags: t.tags, createdAt: now, updatedAt: now,
            ));
            await _saveTemplates();
            notifyListeners();
            return;
          }
        }
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка добавления шаблона: $e'; notifyListeners();
      }
    }
    _templates.add(t);
    await _saveTemplates();
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    if (!_useMock && authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        await authService.apiService.setTemplate({
          'operationPatterns': [{'id': id, 'deleted_at': now}]
        }, operationPatternId: id);
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка удаления шаблона: $e'; notifyListeners();
      }
    }
    _templates.removeWhere((t) => t.id == id);
    await _saveTemplates();
    notifyListeners();
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _templates.map((t) => t.toJson()).toList();
    await prefs.setString('easyfinance_templates', jsonEncode(data));
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('easyfinance_templates');
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _templates = list.map((e) => OperationTemplate.fromLocalJson(e as Map<String, dynamic>)).toList();
    }
    notifyListeners();
  }

  // --- Tags ---

  Future<void> deleteTag(String id) async {
    _tags.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  List<String> getTagsForOperation(Operation op) {
    if (op.tags == null || op.tags!.isEmpty) return [];
    return op.tags!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}
