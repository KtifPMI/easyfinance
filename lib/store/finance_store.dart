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
import '../services/currency_rate_service.dart';
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
  Map<String, double> _rates = {'RUB': 1.0};
  DateTime? _ratesUpdatedAt;
  BudgetInfo? _serverBudget;
  bool _isLoading = false;
  bool _useMock = true;
  String? _error;
  Future<void> _cacheReady = Future.value();
  Future<void> _templatesReady = Future.value();

  FinanceStore({required this.authService, required this.apiClient}) {
    _cacheReady = _loadFromCache();
    _templatesReady = _loadTemplates();
  }

  Future<void> _loadFromCache() async {
    try {
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
    } catch (_) {
      // Ignore a corrupt cache and continue with server data.
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accounts.isNotEmpty) {
      await prefs.setString('easyfinance_cached_accounts', jsonEncode(_accounts.map((a) => a.toJson()).toList()));
    } else {
      await prefs.remove('easyfinance_cached_accounts');
    }
    if (_operations.isNotEmpty) {
      await prefs.setString('easyfinance_cached_operations', jsonEncode(_operations.map((o) => o.toJson()).toList()));
    } else {
      await prefs.remove('easyfinance_cached_operations');
    }
    if (_categories.isNotEmpty) {
      await prefs.setString('easyfinance_cached_categories', jsonEncode(_categories.map((c) => c.toJson()).toList()));
    } else {
      await prefs.remove('easyfinance_cached_categories');
    }
    if (_tags.isNotEmpty) {
      await prefs.setString('easyfinance_cached_tags', jsonEncode(_tags.map((t) => t.toJson()).toList()));
    } else {
      await prefs.remove('easyfinance_cached_tags');
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
  Map<String, double> get rates => _rates;
  DateTime? get ratesUpdatedAt => _ratesUpdatedAt;
  bool get isLoading => _isLoading;
  bool get useMock => _useMock;
  String? get error => _error;

  cat.Category? getCategory(String? id) => id == null ? null : _categories.cast<cat.Category?>().firstWhere((c) => c!.id == id, orElse: () => null);
  Account? getAccount(String? id) => id == null ? null : _accounts.cast<Account?>().firstWhere((a) => a!.id == id, orElse: () => null);

  double get totalBalance => _accounts
      .where((a) => a.includeInTotal && !a.isArchived)
      .fold<double>(0, (sum, a) => sum + CurrencyRateService.convert(a.balance, a.currency, 'RUB', _rates));
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
    final d = DateTime.tryParse(dateIso);
    if (d == null) return false;
    return !d.isBefore(start) && !d.isAfter(end);
  }

  Future<void> fetchAllData() async {
    if (!authService.isAuthenticated) return;
    await Future.wait([_cacheReady, _templatesReady]);
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
    } catch (_) {}

    try {
      _accounts = await api.getAccounts();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {}

    try {
      _operations = await api.getOperations();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {}

    try {
      _categories = await api.getCategories();
      if (_categories.isEmpty) {
        _categories = [...mockCategories];
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {}

    try {
      _tags = await api.getTags();
    } catch (_) {}

    try {
      final apiTemplates = await api.getTemplates();
      _templates = apiTemplates;
      await _saveTemplates();
    } catch (_) {}
    notifyListeners();

    try {
      _serverBudget = await api.getBudget();
    } catch (_) {}

    try {
      _currencies = await api.getCurrencies();
    } catch (_) {}

    try {
      _rates = {'RUB': 1.0, ...await CurrencyRateService.fetchRates()};
      _ratesUpdatedAt = DateTime.now();
    } catch (_) {}

    try {
      _systemCategories = await api.getSystemCategories();
    } catch (_) {}

    final existingGoalIds = _goals.map((g) => g.id).toSet();

    try {
      final targets = await api.getTargets();
      final targetIds = targets.map((t) => t['id']?.toString()).whereType<String>().toSet();
      _goals.removeWhere((g) => targetIds.contains(g.id));
      existingGoalIds.removeAll(targetIds);
      for (final g in targets.where((t) => t['visible']?.toString() != '0').map((g) => Goal.fromJson(g))) {
        existingGoalIds.add(g.id);
        _goals.add(g);
      }
    } catch (_) {}

    try {
      final templateGoals = await api.getGoalTemplates();
      for (final g in templateGoals.map((g) => Goal.fromOpPattern(g))) {
        if (existingGoalIds.contains(g.id)) continue;
        _goals.add(g);
        existingGoalIds.add(g.id);
      }
    } catch (_) {}

    try {
      final pdaGoals = await authService.pdaService.getTargets();
      for (final g in pdaGoals.where((t) => t['visible']?.toString() != '0').map((g) => Goal.fromJson(g))) {
        if (existingGoalIds.contains(g.id)) continue;
        _goals.add(g);
      }
    } catch (_) {}

    _recalcAccountBalances();

    for (var i = 0; i < _budgets.length; i++) {
      final b = _budgets[i];
      final spent = _calcSpentForMonth(b.categoryId);
      _budgets[i] = b.copyWith(spent: spent);
    }
    await _saveBudgets();

    _generateRecommendations();

    _useMock = !authService.isAuthenticated;
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

    String fmt(double v) => v.toStringAsFixed(0);
    String pct(double part, double total) => total > 0 ? ((part / total) * 100).round().toString() : '0';

    // 1 — budget overspent or near limit
    for (final b in _budgets.where((b) => !b.isDeleted)) {
      final cat = _categories.where((c) => c.id == b.categoryId).firstOrNull;
      final name = cat?.name ?? b.name ?? '';
      if (b.spent > b.limit) {
        _recommendations.add(Recommendation(
          id: 'b_overspent_${b.id}', type: 'risk', severity: 'high',
          title: 'Лимит превышен: $name',
          description: 'Потрачено ${fmt(b.spent)} ₽ при лимите ${fmt(b.limit)} ₽.',
          titleArgs: {'name': name},
          descArgs: {'spent': fmt(b.spent), 'limit': fmt(b.limit), 'overspent': fmt(b.spent - b.limit), 'pct': pct(b.spent, b.limit)},
        ));
      } else if (b.spent > b.limit * 0.8) {
        final remaining = b.limit - b.spent;
        _recommendations.add(Recommendation(
          id: 'b_near_${b.id}', type: 'optimization', severity: 'medium',
          title: 'Близок к лимиту: $name',
          description: 'Использовано ${fmt(b.spent)} ₽ из ${fmt(b.limit)} ₽.',
          titleArgs: {'name': name},
          descArgs: {'spent': fmt(b.spent), 'limit': fmt(b.limit), 'pct': pct(b.spent, b.limit), 'remaining': fmt(remaining)},
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
            description: 'На питание уходит ${foodRatio.round()}% дохода.',
            descArgs: {'pct': foodRatio.round().toString(), 'amount': fmt(allFood), 'income': fmt(monthIncome)},
          ));
        } else if (foodRatio > 30) {
          _recommendations.add(Recommendation(
            id: 'food_warning', type: 'optimization', severity: 'medium',
            title: 'Питание отнимает ${foodRatio.round()}% дохода',
            description: 'Потрачено ${fmt(allFood)} ₽ из ${fmt(monthIncome)} ₽.',
            titleArgs: {'pct': foodRatio.round().toString()},
            descArgs: {'amount': fmt(allFood), 'income': fmt(monthIncome)},
          ));
        }
      }
      if (diningCount >= 5 && diningTotal > 0) {
        _recommendations.add(Recommendation(
          id: 'dining_freq', type: 'optimization', severity: 'low',
          title: '$diningCount раз(а) в кафе за месяц',
          description: 'На кафе и рестораны ушло ${fmt(diningTotal)} ₽.',
          titleArgs: {'count': diningCount.toString()},
          descArgs: {'amount': fmt(diningTotal), 'pct': pct(diningTotal, monthIncome)},
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
          _recommendations.add(Recommendation(
            id: 'no_budget_${entry.key}', type: 'optimization', severity: 'medium',
            title: 'Нет бюджета для «${cat.name}»',
            description: 'Потрачено ${fmt(entry.value)} ₽.',
            actionType: 'create_budget',
            actionPayload: entry.key,
            titleArgs: {'name': cat.name},
            descArgs: {'amount': fmt(entry.value), 'pct': pct(entry.value, monthExpense)},
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
          description: 'На жильё уходит ${fmt(housingTotal)} ₽ из ${fmt(monthIncome)} ₽.',
          titleArgs: {'pct': housingRatio.round().toString()},
          descArgs: {'amount': fmt(housingTotal), 'income': fmt(monthIncome), 'pct': housingRatio.round().toString()},
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
          description: 'Доход ${fmt(monthIncome)} ₽, расходы ${fmt(monthExpense)} ₽.',
          descArgs: {'income': fmt(monthIncome), 'expense': fmt(monthExpense), 'deficit': fmt(monthExpense - monthIncome)},
        ));
      } else if (savingsRate < 10) {
        final saveAmt = monthIncome - monthExpense;
        _recommendations.add(Recommendation(
          id: 'low_savings', type: 'risk', severity: 'medium',
          title: 'Низкая норма сбережения',
          description: 'Откладывается ${fmt(saveAmt)} ₽ (${savingsRate.round()}%).',
          descArgs: {'amount': fmt(saveAmt), 'pct': savingsRate.round().toString(), 'income': fmt(monthIncome), 'target': fmt(monthIncome * 0.2)},
        ));
      } else if (savingsRate >= 20) {
        final saveAmt = monthIncome - monthExpense;
        _recommendations.add(Recommendation(
          id: 'good_savings', type: 'tip', severity: 'low',
          title: 'Хорошая норма сбережения',
          description: 'Отложено ${fmt(saveAmt)} ₽ (${savingsRate.round()}).',
          descArgs: {'amount': fmt(saveAmt), 'pct': savingsRate.round().toString(), 'income': fmt(monthIncome)},
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
          final p = (e.value / monthExpense * 100).round();
          return '${cat?.name ?? e.key} ${fmt(e.value)} ₽ ($p%)';
        }).join(', ');
        _recommendations.add(Recommendation(
          id: 'top_cats', type: 'tip', severity: 'low',
          title: 'Структура расходов',
          description: 'Основные статьи: $parts.',
          descArgs: {'items': parts},
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
        description: 'Рекомендуется резерв 3–6 месячных расходов ($suggested ₽).',
        actionType: 'create_goal',
        actionPayload: 'emergency',
        descArgs: {'amount': suggested},
      ));
    }

    // 8 — idle cash
    for (final a in _accounts) {
      if (a.icon == 'cash' && a.balance > 50000) {
        _recommendations.add(Recommendation(
          id: 'idle_cash_${a.id}', type: 'optimization', severity: 'low',
          title: '${fmt(a.balance)} ₽ наличными без движения',
          description: 'На счету «${a.name}» ${fmt(a.balance)} ₽.',
          titleArgs: {'amount': fmt(a.balance)},
          descArgs: {'name': a.name, 'amount': fmt(a.balance)},
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
          description: 'Накоплено ${fmt(g.currentAmount)} ₽ из ${fmt(g.targetAmount)} ₽.',
          titleArgs: {'title': g.title},
          descArgs: {'current': fmt(g.currentAmount), 'target': fmt(g.targetAmount), 'pct': progress.round().toString(), 'remaining': fmt(g.targetAmount - g.currentAmount)},
        ));
      }
    }

    // fallback: if nothing generated, add a friendly tip
    if (_recommendations.isEmpty) {
      _recommendations.add(Recommendation(
        id: 'all_good', type: 'tip', severity: 'low',
        title: 'Всё в порядке!',
        description: 'Сейчас нет рекомендаций. Добавляйте операции и ставьте цели.',
      ));
    }
  }

  Future<void> addOperation(Operation op) async {
    _error = null;
    if (authService.isAuthenticated) {
      try {
        final now = DateTime.now();
        final operationDate = DateTime.tryParse(op.date) ?? now;
        final dateStr = '${operationDate.year}-${operationDate.month.toString().padLeft(2, '0')}-${operationDate.day.toString().padLeft(2, '0')}';
        final timeStr = '${operationDate.hour.toString().padLeft(2, '0')}:${operationDate.minute.toString().padLeft(2, '0')}:${operationDate.second.toString().padLeft(2, '0')}';
        final createdAt = formatApiDateTime(now);
        final amount = op.type == 'income' ? op.amount : -op.amount;
        final clientId = now.microsecondsSinceEpoch;

        final response = await authService.apiService.addOperation({
          'operations': [{
            'type': _typeToApi(op.type),
            'user_id': apiClient.userId ?? '',
            'account_id': op.accountId,
            if (op.categoryId != null) 'category_id': op.categoryId,
            'currency_id': _currencyIdForAccount(op.accountId),
            'amount': amount.toStringAsFixed(2),
            'date': dateStr,
            'time': timeStr,
            if (op.toAccountId != null) 'transfer_account_id': op.toAccountId,
            if (op.toAccountId != null) 'transfer_amount': op.amount.toStringAsFixed(2),
            if (op.comment != null) 'comment': op.comment,
            if (op.tags != null) 'tags': op.tags,
            'accepted': true,
            'client_id': clientId,
            'created_at': createdAt,
            'updated_at': createdAt,
            'deleted_at': null,
          }]
        });
        final serverOperations = response['operations'] as List<dynamic>?;
        final serverId = serverOperations?.isNotEmpty == true
            ? (serverOperations!.first as Map<String, dynamic>)['id']?.toString()
            : null;
        if (serverId == null || serverId.isEmpty) {
          throw ApiException('Сервер не вернул ID операции', 'MISSING_OPERATION_ID');
        }
        op = op.copyWith(id: serverId);
      } on ApiException catch (e) {
        _error = e.message;
        notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка добавления: $e';
        notifyListeners();
        return;
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
    _error = null;
    if (authService.isAuthenticated) {
      try {
        final now = DateTime.now();
        final operationDate = DateTime.tryParse(op.date) ?? now;
        final dateStr = '${operationDate.year}-${operationDate.month.toString().padLeft(2, '0')}-${operationDate.day.toString().padLeft(2, '0')}';
        final timeStr = '${operationDate.hour.toString().padLeft(2, '0')}:${operationDate.minute.toString().padLeft(2, '0')}:${operationDate.second.toString().padLeft(2, '0')}';
        final updatedAt = formatApiDateTime(now);
        final amount = op.type == 'income' ? op.amount : -op.amount;

        await authService.apiService.setOperation({
          'operations': [{
            'id': op.id,
            'type': _typeToApi(op.type),
            'account_id': op.accountId,
            if (op.categoryId != null) 'category_id': op.categoryId,
            'currency_id': _currencyIdForAccount(op.accountId),
            'amount': amount.toStringAsFixed(2),
            'date': dateStr,
            'time': timeStr,
            'transfer_account_id': op.toAccountId,
            'transfer_amount': op.toAccountId != null ? op.amount.toStringAsFixed(2) : null,
            if (op.comment != null) 'comment': op.comment,
            if (op.tags != null) 'tags': op.tags,
            'accepted': true,
            'updated_at': updatedAt,
            'deleted_at': null,
          }]
        });
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка обновления: $e'; notifyListeners();
        return;
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
    _error = null;
    final op = _operations.firstWhere((o) => o.id == id);
    if (authService.isAuthenticated) {
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
        return;
      } catch (e) {
        _error = 'Ошибка удаления: $e'; notifyListeners();
        return;
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
    _error = null;
    if (authService.isAuthenticated) {
      try {
        final now = _fmtSimpleDt();
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
        throw ApiException('Сервер не вернул ID счёта', 'MISSING_ACCOUNT_ID');
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка добавления счёта: $e'; notifyListeners();
        return;
      }
    }
    _accounts.add(account);
    await _saveCache();
    notifyListeners();
  }

  Future<void> updateAccount(Account account) async {
    _error = null;
    if (authService.isAuthenticated) {
      try {
        final now = _fmtSimpleDt();
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
        return;
      } catch (e) {
        _error = 'Ошибка обновления счёта: $e'; notifyListeners();
        return;
      }
    }
    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) _accounts[idx] = account;
    _recalcAccountBalances();
    await _saveCache();
    notifyListeners();
  }

  Future<void> deleteAccount(String id) async {
    _error = null;
    if (authService.isAuthenticated) {
      try {
        final account = _accounts.where((a) => a.id == id).firstOrNull;
        if (account == null) {
          _error = 'Счёт не найден';
          notifyListeners();
          return;
        }
        final now = _fmtSimpleDt();
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
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка удаления счёта: $e'; notifyListeners();
        return;
      }
    }
    _accounts.removeWhere((a) => a.id == id);
    await _saveCache();
    notifyListeners();
  }

  // --- Categories ---

  Future<void> addCategory(cat.Category c) async {
    _error = null;
    if (authService.isAuthenticated) {
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
        throw ApiException('Сервер не вернул ID категории', 'MISSING_CATEGORY_ID');
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка добавления категории: $e'; notifyListeners();
        return;
      }
    }
    _categories.add(c);
    await _saveCache();
    notifyListeners();
  }

  Future<void> updateCategory(cat.Category c) async {
    _error = null;
    if (authService.isAuthenticated) {
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
        return;
      } catch (e) {
        _error = 'Ошибка обновления категории: $e'; notifyListeners();
        return;
      }
    }
    final idx = _categories.indexWhere((x) => x.id == c.id);
    if (idx >= 0) _categories[idx] = c;
    await _saveCache();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    _error = null;
    if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        await authService.apiService.setCategory({
          'categories': [{'id': id, 'deleted_at': now}]
        }, categoryId: id);
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка удаления категории: $e'; notifyListeners();
        return;
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
    _error = null;
    final spent = _calcSpentForMonth(b.categoryId);
    if (_hasPdaToken()) {
      try {
        final resp = await authService.pdaService.processBudget({
          'category_id': b.categoryId,
          'plan_amount': b.limit.toStringAsFixed(2),
        });
        final serverId = resp['id']?.toString();
        if (serverId != null && serverId.isNotEmpty) {
          _budgets.add(Budget(
            id: serverId, name: b.name, categoryId: b.categoryId,
            limit: b.limit, spent: spent, period: b.period,
          ));
          await _saveBudgets();
          notifyListeners();
          return;
        }
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка создания бюджета: $e'; notifyListeners();
        return;
      }
    }
    _budgets.add(b.copyWith(spent: spent));
    await _saveBudgets();
    notifyListeners();
  }

  Future<void> updateBudget(Budget b) async {
    _error = null;
    if (_hasPdaToken()) {
      try {
        await authService.pdaService.processBudget({
          'id': b.id,
          'category_id': b.categoryId,
          'plan_amount': b.limit.toStringAsFixed(2),
        });
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка обновления бюджета: $e'; notifyListeners();
        return;
      }
    }
    final idx = _budgets.indexWhere((x) => x.id == b.id);
    if (idx >= 0) _budgets[idx] = b;
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
    _error = null;
    if (_hasPdaToken()) {
      try {
        await authService.pdaService.processBudget({
          'id': id,
          'deleted_at': formatApiDateTime(),
        });
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка удаления бюджета: $e'; notifyListeners();
        return;
      }
    }
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
    try {
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
    } catch (_) {
      _budgets = [];
    }
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _fmtSimpleDt() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  String _currencyIdForAccount(String accountId) {
    return _accounts.firstWhere((a) => a.id == accountId, orElse: () => Account(id: '', name: '', balance: 0)).currencyId ?? '1';
  }

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _hasPdaToken() => authService.pdaClient.authToken != null;

  Future<void> addGoal(Goal g) async {
    _error = null;
    if (authService.isAuthenticated) {
      try {
        final resp = await authService.apiService.addTarget({
          'title': g.title,
          'amount': g.targetAmount.toStringAsFixed(2),
          'amount_done': g.currentAmount.toStringAsFixed(2),
          'visible': '1',
          'currency_id': g.currencyId ?? '1',
          'date_begin': g.startDate.isNotEmpty ? g.startDate : _todayDate(),
          if (g.deadline.isNotEmpty) 'date_end': g.deadline,
          if (g.accountId != null) 'account_id': g.accountId,
        });
        final targets = resp['targets'] as List<dynamic>?;
        if (targets != null && targets.isNotEmpty) {
          final serverId = targets[0]['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            _goals.add(Goal(
              id: serverId, title: g.title, targetAmount: g.targetAmount,
              currentAmount: g.currentAmount, startDate: g.startDate.isNotEmpty ? g.startDate : _todayDate(), deadline: g.deadline, icon: g.icon, color: g.color,
              isCompleted: g.isCompleted, accountId: g.accountId,
            ));
            await _saveGoals();
            notifyListeners();
            return;
          }
        }
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка создания цели: $e'; notifyListeners();
      }
    }

    if (_hasPdaToken()) {
      try {
        final resp = await authService.pdaService.processTarget({
          'title': g.title,
          'amount': g.targetAmount.toStringAsFixed(2),
          'amount_done': g.currentAmount.toStringAsFixed(2),
          'end': _fmtDate(g.deadline),
          if (g.accountId != null) 'account': g.accountId!,
        });
        final serverId = resp['id']?.toString();
        if (serverId != null && serverId.isNotEmpty) {
          _error = null;
          _goals.add(Goal(
            id: serverId, title: g.title, targetAmount: g.targetAmount,
            currentAmount: g.currentAmount, deadline: g.deadline, icon: g.icon, color: g.color,
            isCompleted: g.isCompleted, accountId: g.accountId,
          ));
          await _saveGoals();
          notifyListeners();
          return;
        }
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка создания цели: $e'; notifyListeners();
      }
    }

    if (authService.isAuthenticated) {
      try {
        final api = authService.apiService;
        final now = formatApiDateTime();
        final resp = await api.addGoalTemplate({
          'operationPatterns': [{
            'name': g.title,
            'type': '4',
            'amount': g.targetAmount.toStringAsFixed(2),
            if (g.accountId != null) 'account_id': g.accountId,
            'created_at': now,
            'updated_at': now,
          }]
        });
        final patterns = resp['operationPatterns'] as List<dynamic>?;
        if (patterns != null && patterns.isNotEmpty) {
          final serverId = patterns[0]['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            _error = null;
            _goals.add(Goal(
              id: serverId, title: g.title, targetAmount: g.targetAmount,
              currentAmount: g.currentAmount, deadline: g.deadline, icon: g.icon, color: g.color,
              isCompleted: g.isCompleted, accountId: g.accountId,
            ));
            await _saveGoals();
            notifyListeners();
            return;
          }
        }
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка создания цели: $e'; notifyListeners();
      }
    }

    if (authService.isAuthenticated) return;
    _goals.add(g);
    await _saveGoals();
    notifyListeners();
  }

  Future<void> updateGoal(String id, {double? currentAmount, bool? isCompleted}) async {
    _error = null;
    final idx = _goals.indexWhere((g) => g.id == id);
    if (idx < 0) return;
    final g = _goals[idx];

    if (authService.isAuthenticated) {
      try {
        await authService.apiService.setTarget({
          'title': g.title,
          'amount': g.targetAmount.toStringAsFixed(2),
          'amount_done': (currentAmount ?? g.currentAmount).toStringAsFixed(2),
          'visible': '1',
          'currency_id': g.currencyId ?? '1',
          if (g.startDate.isNotEmpty) 'date_begin': g.startDate,
          if (g.deadline.isNotEmpty) 'date_end': g.deadline,
          if (g.accountId != null) 'account_id': g.accountId,
        }, targetId: id);
        _goals[idx] = g.copyWith(currentAmount: currentAmount, isCompleted: isCompleted);
        await _saveGoals();
        notifyListeners();
        return;
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка обновления цели: $e'; notifyListeners();
      }
    }

    if (_hasPdaToken()) {
      try {
        await authService.pdaService.processTarget({
          'id': id,
          'title': g.title,
          'amount': g.targetAmount.toStringAsFixed(2),
          'amount_done': (currentAmount ?? g.currentAmount).toStringAsFixed(2),
          'end': _fmtDate(g.deadline),
          'done': (isCompleted ?? g.isCompleted) ? '1' : '0',
          if (g.accountId != null) 'account': g.accountId!,
        });
        _error = null;
        _goals[idx] = g.copyWith(currentAmount: currentAmount, isCompleted: isCompleted);
        await _saveGoals();
        notifyListeners();
        return;
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка обновления цели: $e'; notifyListeners();
      }
    } else if (authService.isAuthenticated) {
      try {
        final api = authService.apiService;
        final now = formatApiDateTime();
        await api.setGoalTemplate({
          'operationPatterns': [{
            'id': id,
            'name': g.title,
            'type': '4',
            'amount': g.targetAmount.toStringAsFixed(2),
            if (g.accountId != null) 'account_id': g.accountId,
            'updated_at': now,
          }]
        }, id: id);
        _error = null;
        _goals[idx] = g.copyWith(currentAmount: currentAmount, isCompleted: isCompleted);
        await _saveGoals();
        notifyListeners();
        return;
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка обновления цели: $e'; notifyListeners();
      }
    }

    if (authService.isAuthenticated) return;
    _goals[idx] = g.copyWith(currentAmount: currentAmount, isCompleted: isCompleted);
    await _saveGoals();
    notifyListeners();
  }

  Future<void> depositToGoal(String goalId, double amount, String accountId) async {
    final goal = _goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null || amount <= 0) return;

    _error = null;
    final previousAmount = goal.currentAmount;
    final previousCompleted = goal.isCompleted;
    final newAmount = goal.currentAmount + amount;
    final completed = newAmount >= goal.targetAmount;

    await updateGoal(goalId, currentAmount: newAmount, isCompleted: completed);
    if (_error != null) return;

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

    await addOperation(Operation(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      type: 'expense',
      amount: amount,
      date: DateTime.now().toIso8601String(),
      accountId: accountId,
      categoryId: categoryId,
      comment: '🎯 ${goal.title}',
    ));
    if (_error != null) {
      final operationError = _error;
      await updateGoal(goalId, currentAmount: previousAmount, isCompleted: previousCompleted);
      _error = operationError;
      notifyListeners();
    }
  }

  Future<void> deleteGoal(String id) async {
    _error = null;
    if (authService.isAuthenticated) {
      try {
        await authService.apiService.setTarget({
          'visible': '0',
        }, targetId: id);
        _goals.removeWhere((g) => g.id == id);
        await _saveGoals();
        notifyListeners();
        return;
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка удаления цели: $e'; notifyListeners();
      }
    }

    if (_hasPdaToken()) {
      try {
        await authService.pdaService.deleteTarget(id);
        _error = null;
        _goals.removeWhere((g) => g.id == id);
        await _saveGoals();
        notifyListeners();
        return;
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка удаления цели: $e'; notifyListeners();
      }
    } else if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        await authService.apiService.setGoalTemplate({
          'operationPatterns': [{'id': id, 'deleted_at': now}]
        }, id: id);
        _error = null;
        _goals.removeWhere((g) => g.id == id);
        await _saveGoals();
        notifyListeners();
        return;
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка удаления цели: $e'; notifyListeners();
      }
    }
    if (authService.isAuthenticated) return;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('easyfinance_goals');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _goals = list.map((e) => Goal.fromLocalJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _goals = [];
    }
  }

  // --- Templates ---

  Future<void> addTemplate(OperationTemplate t) async {
    _error = null;
    if (authService.isAuthenticated) {
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
        throw ApiException('Сервер не вернул ID шаблона', 'MISSING_TEMPLATE_ID');
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка добавления шаблона: $e'; notifyListeners();
        return;
      }
    }
    _templates.add(t);
    await _saveTemplates();
    notifyListeners();
  }

  Future<void> deleteTemplate(String id) async {
    _error = null;
    if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        await authService.apiService.setTemplate({
          'operationPatterns': [{'id': id, 'deleted_at': now}]
        }, operationPatternId: id);
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка удаления шаблона: $e'; notifyListeners();
        return;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('easyfinance_templates');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _templates = list.map((e) => OperationTemplate.fromLocalJson(e as Map<String, dynamic>)).toList();
      }
      notifyListeners();
    } catch (_) {
      _templates = [];
    }
  }

  // --- Tags ---

  Future<void> deleteTag(String id) async {
    _tags.removeWhere((t) => t.id == id);
    await _saveCache();
    notifyListeners();
  }

  List<String> getTagsForOperation(Operation op) {
    if (op.tags == null || op.tags!.isEmpty) return [];
    return op.tags!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}
