import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart' as cat;
import '../models/goal.dart';
import '../models/operation.dart';
import '../models/operation_template.dart';
import '../models/recommendation.dart';
import '../services/operations_db.dart';
import '../models/recommendation_prefs.dart';
import '../models/tag.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../utils/account_utils.dart';
import '../services/api_service.dart';
import '../services/mock_data.dart' show mockCategories;
import '../services/currency_rate_service.dart';
import '../services/currency_prefs_service.dart';
import '../services/rate_history_storage.dart';
import '../store/planned_payment_store.dart';
import '../utils/format.dart';
import '../utils/currency_utils.dart';
import '../utils/calc.dart';

class FinanceStore extends ChangeNotifier with WidgetsBindingObserver {
  void refresh() => _scheduleNotify();
  final AuthService authService;
  final ApiClient apiClient;
  User? _currentUser;
  List<Account> _accounts = [];
  List<Operation> _operations = [];
  List<cat.Category> _categories = [];
  List<Budget> _budgets = [];
  List<Goal> _goals = [];
  List<Recommendation> _recommendations = [];
  RecommendationPrefs _recPrefs = RecommendationPrefs();
  List<Tag> _tags = [];
  final Set<String> _deletedTagNames = {};
  final Set<String> _deletedTemplateIds = {};

  bool isTagDeleted(String name) => _deletedTagNames.contains(name.toLowerCase());
  List<OperationTemplate> _templates = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _systemCategories = [];
  Map<String, double> _rates = {'RUB': 1.0};
  DateTime? _ratesUpdatedAt;
  List<String> _watchedCurrencies = [];
  final Map<String, Map<String, double>> _histRates = {};
  static const int _maxHistRates = 90;
  String _displayCurrency = 'RUB';
  BudgetInfo? _serverBudget;
  bool _isLoading = false;
  bool _loadingAllOps = false;
  bool _balanceLoaded = false;
  bool _allOperationsLoaded = false;
  bool _useMock = true;
  bool showKopeks = true;
  bool showKopeksInOps = true;
  bool _authExpired = false;
  String? _error;
  bool _notifyScheduled = false;
  bool _dataLoaded = false;
  final Set<String> _changedOpIds = {};
  final Set<String> _deletedOpIds = {};
  Future<void> _cacheReady = Future.value();
  Future<void> _templatesReady = Future.value();
  PlannedPaymentStore? _plannedPayments;

  double _cachedTotalBalance = 0;
  double _cachedMoneyBalance = 0;
  double _cachedMonthIncome = 0;
  double _cachedMonthExpense = 0;
  List<Operation>? _cachedFilteredOps;
  bool _opsDirty = true;
  final Map<String, List<String>> _tagsCache = {};
  Map<String, cat.Category> _catById = {};
  Map<String, Account> _accountById = {};
  List<Operation>? _cachedCurOps;
  List<Operation>? _cachedPrevOps;
  FinHealthIndicators? _cachedFinHealth;

  void _rebuildLookups() {
    _catById = {for (final c in _categories) c.id: c};
    _accountById = {for (final a in _accounts) a.id: a};
    _invalidateOpCaches();
  }

  void _invalidateOpCaches() {
    _tagsCache.clear();
    _cachedCurOps = null;
    _cachedPrevOps = null;
    _cachedFinHealth = null;
    _opsDirty = true;
  }

  FinanceStore({required this.authService, required this.apiClient, PlannedPaymentStore? plannedPayments})
      : _plannedPayments = plannedPayments {
    apiClient.onAuthExpired = markAuthExpired;
    bindFormatSettings(showKopeks, showKopeksInOps);
    _cacheReady = _loadFromCache();
    _templatesReady = _loadTemplates();
    _loadRecPrefs();
    _loadFormatPrefs();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && authService.isAuthenticated && !_isLoading) {
      if (!_dataLoaded || _accounts.isEmpty) {
        fetchAllData();
      }
    }
  }

  void setPlannedPaymentStore(PlannedPaymentStore store) => _plannedPayments = store;

  bool get authExpired => _authExpired;

  void markAuthExpired() {
    if (_authExpired) return;
    _authExpired = true;
    _scheduleNotify();
  }

  void clearAuthExpired() {
    if (!_authExpired) return;
    _authExpired = false;
    _scheduleNotify();
  }

  Future<void> _loadRecPrefs() async {
    _recPrefs = await RecommendationPrefs.load();
  }

  Future<void> _applyFavoriteStates() async {
    final prefs = await SharedPreferences.getInstance();
    for (int i = 0; i < _accounts.length; i++) {
      final isFav = prefs.getBool('fav_${_accounts[i].id}') ?? false;
      if (isFav) _accounts[i] = _accounts[i].copyWith(isFavorite: true);
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
    final accountsRaw = prefs.getString('easyfinance_cached_accounts');
    final categoriesRaw = prefs.getString('easyfinance_cached_categories');
    final tagsRaw = prefs.getString('easyfinance_cached_tags');
    final userRaw = prefs.getString('easyfinance_cached_user');
    if (accountsRaw != null) {
      try {
        final list = jsonDecode(accountsRaw) as List<dynamic>;
        _accounts = list.map((e) => Account.fromLocalJson(e as Map<String, dynamic>)).toList();
        await _applyFavoriteStates();
        _useMock = false;
      } catch (_) {}
    }
    try {
      _operations = await OperationsDb.getAll();
      _opsDirty = true;
      if (_operations.isNotEmpty) _useMock = false;
    } catch (_) {}
    if (categoriesRaw != null) {
      try {
        final list = jsonDecode(categoriesRaw) as List<dynamic>;
        _categories = list.map((e) => cat.Category.fromLocalJson(e as Map<String, dynamic>)).toList();
        _useMock = false;
      } catch (_) {}
    }
    if (tagsRaw != null) {
      try {
        final list = jsonDecode(tagsRaw) as List<dynamic>;
        _tags = list.map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    final deletedRaw = prefs.getString('easyfinance_deleted_tags');
    if (deletedRaw != null) {
      final list = jsonDecode(deletedRaw) as List<dynamic>;
      _deletedTagNames.addAll(list.map((e) => e.toString().toLowerCase()));
    }
    if (userRaw != null) {
      try { _currentUser = User.fromJson(jsonDecode(userRaw) as Map<String, dynamic>); } catch (_) {}
    }
    await _loadBudgets();
    await _loadGoals();
    await _loadDisplayCurrency();
    _watchedCurrencies = await _loadWatchedCurrencies();
    final ratesRaw = prefs.getString('easyfinance_cached_rates');
    if (ratesRaw != null) {
      try {
        final decoded = jsonDecode(ratesRaw) as Map<String, dynamic>;
        _rates = {'RUB': 1.0, ...decoded.map((k, v) => MapEntry(k, (v as num).toDouble()))};
        final ratesAtRaw = prefs.getString('easyfinance_cached_rates_at');
        if (ratesAtRaw != null) _ratesUpdatedAt = DateTime.tryParse(ratesAtRaw);
      } catch (_) {}
    }
    _rebuildLookups();
    _recalcCachedTotals();
    _balanceLoaded = true;
    _scheduleNotify();

    Future.delayed(Duration.zero, () async {
      _recalcBudgetSpent();
      _generateRecommendations();
      await _preloadHistoricalRates();
      if (hasListeners) _scheduleNotify();
    });
  } catch (_) {
      // Ignore a corrupt cache and continue with server data.
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accounts.isNotEmpty) {
      await prefs.setString('easyfinance_cached_accounts', jsonEncode(_accounts.map((a) => a.toJson()).toList()));
    }
    try {
      if (_changedOpIds.isNotEmpty || _deletedOpIds.isNotEmpty) {
        final changedOps = _operations.where((op) => _changedOpIds.contains(op.id)).toList();
        await OperationsDb.saveDelta(changedOps, deletedIds: _deletedOpIds.toList());
        _changedOpIds.clear();
        _deletedOpIds.clear();
      } else if (_opsDirty && _operations.isNotEmpty) {
        await OperationsDb.saveAll(_operations);
      }
    } catch (_) {}
    if (_categories.isNotEmpty) {
      await prefs.setString('easyfinance_cached_categories', jsonEncode(_categories.map((c) => c.toJson()).toList()));
    }
    if (_tags.isNotEmpty) {
      await prefs.setString('easyfinance_cached_tags', jsonEncode(_tags.map((t) => t.toJson()).toList()));
    }
    if (_deletedTagNames.isNotEmpty) {
      await prefs.setString('easyfinance_deleted_tags', jsonEncode(_deletedTagNames.toList()));
    }
    if (_currentUser != null) {
      await prefs.setString('easyfinance_cached_user', jsonEncode(_currentUser!.toJson()));
    }
    if (_rates.isNotEmpty) {
      await prefs.setString('easyfinance_cached_rates', jsonEncode(_rates));
      if (_ratesUpdatedAt != null) {
        await prefs.setString('easyfinance_cached_rates_at', _ratesUpdatedAt!.toIso8601String());
      }
    }
    await _saveBudgets();
    await _saveGoals();
  }

  void saveUser(User user) {
    _currentUser = user;
    _scheduleNotify();
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
    await prefs.remove('display_currency');
    final favKeys = prefs.getKeys().where((k) => k.startsWith('fav_')).toList();
    for (final k in favKeys) {
      await prefs.remove(k);
    }
    await OperationsDb.deleteAll();
    await authService.logout();
    _currentUser = null;
    _accounts = [];
    _operations = [];
    _opsDirty = true;
    _categories = [];
    _budgets = [];
    _goals = [];
    _tags = [];
    _templates = [];
    _useMock = true;
    _allOperationsLoaded = false;
    _scheduleNotify();
  }

  bool get isAuthenticated => authService.isAuthenticated;
  bool get allOperationsLoaded => _allOperationsLoaded;
  bool get loadingAllOps => _loadingAllOps;
  User? get currentUser => _currentUser;
  List<Account> get accounts => _accounts;
  List<Operation> get operations {
    if (_opsDirty || _cachedFilteredOps == null) {
      _cachedFilteredOps = _operations.where((o) => !o.isDeleted).toList();
      _opsDirty = false;
    }
    return _cachedFilteredOps!;
  }
  List<cat.Category> get categories => _categories;
  List<Budget> get budgets => _budgets.where((b) => !b.isDeleted).toList();
  List<Goal> get goals => _goals;
  List<Recommendation> get recommendations => _recommendations;
  RecommendationPrefs get recPrefs => _recPrefs;
  List<Tag> get tags => _tags;
  List<OperationTemplate> get templates => _templates;
  List<Map<String, dynamic>> get currencies => _currencies;
  List<Map<String, dynamic>> get systemCategories => _systemCategories;
  BudgetInfo? get serverBudget => _serverBudget;
  Map<String, double> get rates => _rates;
  DateTime? get ratesUpdatedAt => _ratesUpdatedAt;
  List<String> get watchedCurrencies => _watchedCurrencies;

  Future<void> updateRecPrefs(RecommendationPrefs newPrefs) async {
    _recPrefs = newPrefs;
    await _recPrefs.save();
    _generateRecommendations();
    _scheduleNotify();
  }

  Future<List<String>> _loadWatchedCurrencies() async {
    final saved = await CurrencyPrefsService.load();
    if (saved.isNotEmpty) return saved;
    final accountCurrencies = _accounts.map((a) => a.currency).toSet().toList();
    return deriveWatchedCurrencies(_currentUser?.currency, accountCurrencies);
  }

  Future<void> setWatchedCurrencies(List<String> codes) async {
    _watchedCurrencies = codes;
    await CurrencyPrefsService.save(codes);
    _scheduleNotify();
  }

  String get displayCurrency => _displayCurrency;
  String get displayCurrencySymbol => currencySymbol(_displayCurrency);

  Future<void> setDisplayCurrency(String code) async {
    _displayCurrency = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_currency', code);
    _recalcCachedTotals();
    _generateRecommendations();
    _scheduleNotify();
  }

  Future<void> _loadDisplayCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('display_currency');
    if (saved != null && allCurrencyCodes.contains(saved)) {
      _displayCurrency = saved;
    } else {
      _displayCurrency = _currentUser?.currency ?? 'RUB';
    }
  }

  Future<void> _loadFormatPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    showKopeks = prefs.getBool('easyfinance_show_kopeks') ?? true;
    showKopeksInOps = prefs.getBool('easyfinance_show_kopeks_ops') ?? true;
    bindFormatSettings(showKopeks, showKopeksInOps);
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    Future.microtask(() {
      _notifyScheduled = false;
      if (hasListeners) notifyListeners();
    });
  }

  void _trimHistRates() {
    if (_histRates.length <= _maxHistRates) return;
    final sortedKeys = _histRates.keys.toList()..sort();
    final toRemove = sortedKeys.take(_histRates.length - _maxHistRates);
    for (final key in toRemove) {
      _histRates.remove(key);
    }
  }

  String fmt(double amount, {String fromCurrency = 'RUB', String? date}) {
    Map<String, double> rates = _rates;
    if (date != null && _histRates.containsKey(date)) {
      rates = _histRates[date]!;
    }
    final converted = CurrencyRateService.convert(amount, fromCurrency, _displayCurrency, rates);
    return formatMoney(converted, currency: _displayCurrency);
  }

  String fmtOps(double amount, {String fromCurrency = 'RUB', String? date}) {
    Map<String, double> rates = _rates;
    if (date != null && _histRates.containsKey(date)) {
      rates = _histRates[date]!;
    }
    final converted = CurrencyRateService.convert(amount, fromCurrency, _displayCurrency, rates);
    return formatMoneyOps(converted, currency: _displayCurrency);
  }

  bool get isLoading => _isLoading;
  bool get useMock => _useMock;
  String? get error => _error;

  cat.Category? getCategory(String? id) {
    if (id == null) return null;
    return _catById[id];
  }
  Account? getAccount(String? id) => id == null ? null : _accounts.cast<Account?>().firstWhere((a) => a!.id == id, orElse: () => null);

  double get totalBalance => _cachedTotalBalance;
  double get moneyBalance => _cachedMoneyBalance;
  bool get balanceLoaded => _balanceLoaded;

  FinHealthIndicators get finHealth => _cachedFinHealth ??= calcFinHealth(_accounts, _operations, _budgets, _rates);

  double accountActualBalance(Account a) {
    double bal = a.balance;
    for (final op in _operations) {
      if (!op.isPending) continue;
      if (op.accountId == a.id) {
        if (op.type == 'expense') bal -= op.amount;
        else if (op.type == 'income') bal += op.amount;
        else if (op.type == 'transfer') bal -= op.amount;
      }
      if (op.type == 'transfer' && op.toAccountId == a.id) {
        final src = _accountById[op.accountId];
        if (op.transferAmount != null && op.transferAmount! > 0) {
          bal += op.transferAmount!;
        } else if (src != null && src.currency != a.currency) {
          bal += CurrencyRateService.convert(op.amount, src.currency, a.currency, _ratesForOp(op));
        } else {
          bal += op.amount;
        }
      }
    }
    return bal;
  }
  double _amountInRub(Operation o) {
    final acc = getAccount(o.accountId);
    final from = acc?.currency ?? o.currency;
    final dateKey = o.date.length >= 10 ? o.date.substring(0, 10) : null;
    final rates = (dateKey != null && _histRates.containsKey(dateKey)) ? _histRates[dateKey]! : _rates;
    return CurrencyRateService.convert(o.amount, from, 'RUB', rates);
  }

  double get monthIncome => _cachedMonthIncome;
  double get monthExpense => _cachedMonthExpense;

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

  Future<void> _preloadHistoricalRates() async {
    final dates = _operations.map((o) => o.date.substring(0, 10)).toSet();
    for (final dateStr in dates) {
      if (_histRates.containsKey(dateStr)) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      final rates = await RateHistoryStorage.getRates(date);
      if (rates != null) {
        _histRates[dateStr] = rates;
      }
    }
    _trimHistRates();
  }

  bool _fetching = false;
  Future<void> retryRates() async {
    try {
      final c = await authService.apiService.getCurrencies();
      _currencies = c;
      final r = <String, double>{'RUB': 1.0};
      for (final cur in c) {
        final id = cur['id']?.toString();
        final code = currencyIdToCode[id];
        final rate = double.tryParse(cur['rate']?.toString() ?? '0') ?? 0;
        if (rate > 0 && code != null) r[code] = rate;
      }
      if (r.length > 1) {
        _rates = r;
        _ratesUpdatedAt = DateTime.now();
        _recalcCachedTotals();
        _generateRecommendations();
      }
    } catch (e) {
      debugPrint('retryRates error: $e');
    }
    _scheduleNotify();
  }

  Future<void> fetchAllData() async {
    if (!authService.isAuthenticated) return;
    if (_fetching) return;
    _fetching = true;
    try {
    await Future.wait([_cacheReady, _templatesReady]);
    final bool hasCache = _accounts.isNotEmpty || _operations.isNotEmpty;
    if (!hasCache) {
      _isLoading = true;
    }
    _error = null;
    if (!hasCache) {
      _balanceLoaded = false;
    }
    _scheduleNotify();

    try {
    await Future.wait([
      syncPendingOperations(),
      syncPendingAccounts(),
      syncPendingCategories(),
      syncPendingTemplates(),
    ]);
    } catch (_) {}
    final pendingOps = _operations.where((op) => op.isPending).toList();

    final api = authService.apiService;
    final from3m = DateTime.now().subtract(const Duration(days: 90));

    await Future.wait([
      api.getUser().then((u) {
        _currentUser = u;
        if (u.id.isNotEmpty && apiClient.userId != u.id) {
          apiClient.setAuth(accessToken: apiClient.accessToken ?? '', userId: u.id);
        }
        return u;
      }).catchError((e) { debugPrint('getUser error: $e'); return null as dynamic; }),

      api.getAccounts().then((accs) {
        final pendingAcc = _accounts.where((a) => a.isPending).toList();
        _accounts = accs;
        final accIds = _accounts.map((a) => a.id).toSet();
        for (final p in pendingAcc) { if (!accIds.contains(p.id)) _accounts.add(p); }
        return accs;
      }).catchError((e) { _error ??= 'Ошибка загрузки счетов: $e'; return <Account>[]; }),
    ], eagerError: false);

    _recalcCachedTotals();
    _scheduleNotify();

    List<dynamic> results = [];
    try {
    results = await Future.wait([
      api.getOperations(from: _iso8601Date(from3m)).then((ops) {
        _operations = ops;
        _opsDirty = true;
        final serverIds = _operations.map((o) => o.id).toSet();
        for (final p in pendingOps) {
          if (!serverIds.contains(p.id)) {
            final pd = DateTime.tryParse(p.date);
            if (pd != null && !pd.isBefore(from3m)) _operations.insert(0, p);
          }
        }
        debugPrint('Operations loaded: ${_operations.length} (server ${ops.length} + pending in window)');
        return ops;
      }).catchError((e) {
        debugPrint('getOperations error (keeping cache): $e');
        _error ??= 'Ошибка загрузки операций: $e';
        return <Operation>[];
      }),

      apiClient.getCategoriesV2().then((rawCats) {
        _buildSystemIconMap(rawCats);
        final pendingCats = _categories.where((c) => c.isPending).toList();
        _categories = rawCats.map((j) => cat.Category.fromJson(j)).toList();
        if (_categories.isEmpty) _categories = [...mockCategories];
        debugPrint('Categories loaded: ${_categories.length}');
        if (_categories.isNotEmpty) {
          debugPrint('First 3 cat IDs: ${_categories.take(3).map((c) => c.id).join(', ')}');
        }
        final catIds = _categories.map((c) => c.id).toSet();
        for (final p in pendingCats) { if (!catIds.contains(p.id)) _categories.add(p); }
        return rawCats;
      }).catchError((e) { _error ??= 'Ошибка загрузки категорий: $e'; return <Map<String, dynamic>>[]; }),

      api.getTags().then((server) {
        final localOnly = _tags.where((t) => t.id.isEmpty).toList();
        final merged = <Tag>[...server];
        for (final l in localOnly) { if (!merged.any((t) => t.name.toLowerCase() == l.name.toLowerCase())) merged.add(l); }
        _tags = merged;
        return server;
      }).catchError((e) { debugPrint('getTags error: $e'); return <Tag>[]; }),

      api.getTemplates().then((apiTemplates) {
        final pendingTpl = _templates.where((t) => t.isPending).toList();
        _templates = apiTemplates.where((t) => !t.isDeleted && !_deletedTemplateIds.contains(t.id)).toList();
        final tplIds = _templates.map((t) => t.id).toSet();
        for (final p in pendingTpl) { if (!tplIds.contains(p.id)) _templates.add(p); }
        return apiTemplates;
      }).catchError((e) { debugPrint('getTemplates error: $e'); return <OperationTemplate>[]; }),

      api.getBudget().then((b) { _serverBudget = b; return b; }).catchError((e) { debugPrint('getBudget error: $e'); return null as dynamic; }),
      api.getCurrencies().then((c) {
        _currencies = c;
        final r = <String, double>{'RUB': 1.0};
        for (final cur in c) {
          final id = cur['id']?.toString();
          final code = currencyIdToCode[id];
          final rate = double.tryParse(cur['rate']?.toString() ?? '0') ?? 0;
          if (rate > 0 && code != null) r[code] = rate;
        }
        if (r.length > 1) {
          _rates = r;
          _ratesUpdatedAt = DateTime.now();
        }
        return c;
      }).catchError((e) { debugPrint('getCurrencies error: $e'); return null as dynamic; }),
      api.getSystemCategories().then((sc) { _systemCategories = sc; return sc; }).catchError((e) { debugPrint('getSystemCategories error: $e'); return null as dynamic; }),
      api.getBudgetCategories().then((bc) {
        final seen = <String>{};
        final unique = <Map<String, dynamic>>[];
        for (final b in bc) {
          final catId = b['category_id']?.toString() ?? '';
          if (catId.isNotEmpty && seen.contains(catId)) continue;
          seen.add(catId);
          unique.add(b);
        }
        _budgets = unique.map((b) => Budget(
          id: b['id']?.toString() ?? '',
          categoryId: b['category_id']?.toString() ?? '',
          limit: double.tryParse(b['planned']?.toString() ?? '0') ?? 0,
          spent: double.tryParse(b['spent']?.toString() ?? '0') ?? 0,
          period: b['period']?.toString() ?? 'monthly',
          isDeleted: b['deleted_at'] != null && b['deleted_at'].toString().isNotEmpty,
        )).toList();
        return bc;
      }).catchError((e) { debugPrint('getBudgetCategories error: $e'); return <Map<String, dynamic>>[]; }),
      api.getTargets().catchError((e) { debugPrint('getTargets error: $e'); return <Map<String, dynamic>>[]; }),
      api.getGoalTemplates().catchError((e) { debugPrint('getGoalTemplates error: $e'); return <Map<String, dynamic>>[]; }),
    ], eagerError: false);
    } catch (_) {}

    _recalcCachedTotals();
    _balanceLoaded = true;
    _scheduleNotify();

    await Future.wait([
      _applyFavoriteStates(),
      _syncPendingTags(),
      _plannedPayments?.syncFromServer().catchError((e) { debugPrint('planned payments sync error: $e'); }) ?? Future.value(),
    ]);

    final targets = results[9] as List<dynamic>? ?? [];
    final templateGoals = results[10] as List<dynamic>? ?? [];
    final existingGoalIds = _goals.map((g) => g.id).toSet();
    final targetIds = targets.map((t) => t['id']?.toString()).whereType<String>().toSet();
    _goals.removeWhere((g) => targetIds.contains(g.id));
    existingGoalIds.removeAll(targetIds);
    for (final g in targets.where((t) => t['visible']?.toString() != '0').map((g) => Goal.fromJson(g))) {
      existingGoalIds.add(g.id);
      _goals.add(g);
    }
    for (final g in templateGoals.map((g) => Goal.fromOpPattern(g))) {
      if (!existingGoalIds.contains(g.id)) { _goals.add(g); existingGoalIds.add(g.id); }
    }

    _rebuildLookups();
    _recalcBudgetSpent();
    _recalcCachedTotals();
    _generateRecommendations();

    _useMock = !authService.isAuthenticated;
    _isLoading = false;
    _dataLoaded = true;
    _fetching = false;
    await _saveCache();
    _scheduleNotify();

    Future.delayed(Duration.zero, () async {
      await _preloadHistoricalRates();
      if (hasListeners) _scheduleNotify();
    });
    } catch (_) { _fetching = false; }
  }

  Future<void> loadMoreOperations(DateTime from, DateTime to) async {
    if (!authService.isAuthenticated) return;
    final api = authService.apiService;
    final pendingOps = _operations.where((op) => op.isPending).toList();
    try {
      final fromStr = _iso8601Date(from);
      final toStr = _iso8601Date(to);
      final serverOps = await api.getOperations(from: fromStr, to: toStr);
      final existingIds = _operations.map((o) => o.id).toSet();
      final newOps = serverOps.where((o) => !existingIds.contains(o.id)).toList();
      for (final p in pendingOps) {
        if (!existingIds.contains(p.id)) {
          final pd = DateTime.tryParse(p.date);
          if (pd != null && !pd.isBefore(from) && !pd.isAfter(to)) newOps.add(p);
        }
      }
      if (newOps.isNotEmpty) {
        _operations.addAll(newOps);
        _invalidateOpCaches();
        _recalcBudgetSpent();
        await _saveCache();
        _scheduleNotify();
      }
    } catch (e) {
      debugPrint('loadMoreOperations error: $e');
    }
  }

  Future<void> loadAllOperations() async {
    if (!authService.isAuthenticated || _allOperationsLoaded || _loadingAllOps) return;
    _loadingAllOps = true;
    _scheduleNotify();
    final api = authService.apiService;
    try {
      final allOps = await api.getOperations();
      final serverIds = allOps.map((o) => o.id).toSet();
      final localOnly = _operations.where((o) => !serverIds.contains(o.id) && !o.isDeleted).toList();
      _operations = [...allOps, ...localOnly];
      _invalidateOpCaches();
      _allOperationsLoaded = true;
      _recalcBudgetSpent();
      _recalcCachedTotals();
      _generateRecommendations();
      await _saveCache();
    } catch (e) {
      debugPrint('loadAllOperations error: $e');
    } finally {
      _loadingAllOps = false;
      _scheduleNotify();
    }
  }

  /// Refreshes only the goals list from the server (targets + templates).
  Future<void> refreshGoals() async {
    if (!authService.isAuthenticated) return;
    final api = authService.apiService;
    try {
      final targets = await api.getTargets();
      final targetIds = targets.map((t) => t['id']?.toString()).whereType<String>().toSet();
      _goals.removeWhere((g) => targetIds.contains(g.id));
      for (final g in targets.where((t) => t['visible']?.toString() != '0').map((g) => Goal.fromJson(g))) {
        _goals.add(g);
      }
    } catch (_) {}
    try {
      final templateGoals = await api.getGoalTemplates();
      final ids = _goals.map((g) => g.id).toSet();
      for (final g in templateGoals.map((g) => Goal.fromOpPattern(g))) {
        if (ids.contains(g.id)) continue;
        _goals.add(g);
        ids.add(g.id);
      }
    } catch (e) {
      debugPrint('getGoalTemplates error: $e');
    }
    _scheduleNotify();
  }

  static DateTime? _lastRecsAt;
  static int _lastRecsHash = 0;
  void _scheduleRecommendations() {
    final now = DateTime.now();
    if (_lastRecsAt != null && now.difference(_lastRecsAt!).inSeconds < 2) return;
    _lastRecsAt = now;
    final hash = _operations.length ^ _budgets.length ^ _goals.length ^ _categories.length;
    if (hash == _lastRecsHash && _recommendations.isNotEmpty) return;
    _lastRecsHash = hash;
    _generateRecommendations();
  }

  void _generateRecommendations() {
    _recommendations = [];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final prevMonthEnd = DateTime(now.year, now.month, 0);

    if (_cachedCurOps == null) {
      _cachedCurOps = _operations.where((o) {
        final d = DateTime.tryParse(o.date);
        return d != null && !d.isBefore(monthStart) && !d.isAfter(monthEnd);
      }).toList();
    }
    if (_cachedPrevOps == null) {
      _cachedPrevOps = _operations.where((o) {
        final d = DateTime.tryParse(o.date);
        return d != null && !d.isBefore(prevMonthStart) && !d.isAfter(prevMonthEnd);
      }).toList();
    }
    final curOps = _cachedCurOps!;
    final prevOps = _cachedPrevOps!;

    final monthIncome = curOps.where((o) => o.type == 'income').fold(0.0, (s, o) => s + _amountInRub(o));
    final monthExpense = curOps.where((o) => o.type == 'expense').fold(0.0, (s, o) => s + _amountInRub(o));
    final prevIncome = prevOps.where((o) => o.type == 'income').fold(0.0, (s, o) => s + _amountInRub(o));
    final prevExpense = prevOps.where((o) => o.type == 'expense').fold(0.0, (s, o) => s + _amountInRub(o));

    final sym = currencySymbol(_displayCurrency);
    final symBefore = _displayCurrency == 'USD' || _displayCurrency == 'GBP';
    String fmt(double v) {
      final converted = CurrencyRateService.convert(v, 'RUB', _displayCurrency, _rates);
      final sign = converted < 0 ? '-' : '';
      final intPart = converted.abs().toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
      return symBefore ? '$sign$sym$intPart' : '$sign$intPart $sym';
    }
    String pct(double part, double total) => total > 0 ? ((part / total) * 100).round().toString() : '0';

    // 1 — budget overspent or near limit
    for (final b in _budgets.where((b) => !b.isDeleted)) {
      final cat = _catById[b.categoryId];
      final name = cat?.name ?? b.name ?? '';
      if (b.spent > b.limit) {
        _recommendations.add(Recommendation(
          id: 'b_overspent_${b.id}', type: 'risk', severity: 'high',
          title: 'Лимит превышен: $name',
          description: 'Потрачено ${fmt(b.spent)} при лимите ${fmt(b.limit)}.',
          titleArgs: {'name': name},
          descArgs: {'spent': fmt(b.spent), 'limit': fmt(b.limit), 'overspent': fmt(b.spent - b.limit), 'pct': pct(b.spent, b.limit)},
        ));
      } else if (b.spent > b.limit * _recPrefs.budgetNearPct / 100) {
        final remaining = b.limit - b.spent;
        _recommendations.add(Recommendation(
          id: 'b_near_${b.id}', type: 'optimization', severity: 'medium',
          title: 'Близок к лимиту: $name',
          description: 'Использовано ${fmt(b.spent)} из ${fmt(b.limit)}.',
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
      for (final o in curOps.where((o) => o.type == 'expense' && foodCats.contains(o.categoryId))) {
        final cat = _catById[o.categoryId];
        final amt = _amountInRub(o);
        if (cat != null && (cat.name.contains('кафе') || cat.name.contains('ресторан') || cat.name.contains('cafe') || cat.name.contains('restaurant'))) {
          diningTotal += amt;
          diningCount++;
        } else {
          foodTotal += amt;
        }
      }
      final allFood = foodTotal + diningTotal;
      if (allFood > 0) {
        final foodRatio = allFood / monthIncome * 100;
        if (foodRatio > _recPrefs.foodHighPct) {
          _recommendations.add(Recommendation(
            id: 'high_food', type: 'risk', severity: 'high',
            title: 'Высокие расходы на питание',
            description: 'На питание уходит ${foodRatio.round()}% дохода.',
            descArgs: {'pct': foodRatio.round().toString(), 'amount': fmt(allFood), 'income': fmt(monthIncome), 'limit': _recPrefs.foodHighPct.round().toString()},
          ));
        } else if (foodRatio > _recPrefs.foodMediumPct) {
          _recommendations.add(Recommendation(
            id: 'food_warning', type: 'optimization', severity: 'medium',
            title: 'Питание отнимает ${foodRatio.round()}% дохода',
            description: 'Потрачено ${fmt(allFood)} из ${fmt(monthIncome)}.',
            titleArgs: {'pct': foodRatio.round().toString()},
            descArgs: {'amount': fmt(allFood), 'income': fmt(monthIncome), 'limit': _recPrefs.foodMediumPct.round().toString()},
          ));
        }
      }
      if (diningCount >= _recPrefs.diningFrequency && diningTotal > 0) {
        _recommendations.add(Recommendation(
          id: 'dining_freq', type: 'optimization', severity: 'low',
          title: '$diningCount раз(а) в кафе за месяц',
          description: 'На кафе и рестораны ушло ${fmt(diningTotal)}.',
          titleArgs: {'count': diningCount.toString()},
          descArgs: {'amount': fmt(diningTotal), 'pct': pct(diningTotal, monthIncome)},
        ));
      }
    }

    // 3 — no budget for high-spend categories
    final topSpend = <String, double>{};
    for (final o in curOps.where((o) => o.type == 'expense' && o.categoryId != null)) {
      topSpend.update(o.categoryId!, (v) => v + _amountInRub(o), ifAbsent: () => _amountInRub(o));
    }
    final budgetedCats = _budgets.where((b) => !b.isDeleted).map((b) => b.categoryId).toSet();
    final sortedCats = topSpend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedCats.take(3)) {
      if (!budgetedCats.contains(entry.key)) {
        final cat = _catById[entry.key];
        if (cat != null && entry.value > _recPrefs.noBudgetMinSpend) {
          _recommendations.add(Recommendation(
            id: 'no_budget_${entry.key}', type: 'optimization', severity: 'medium',
            title: 'Нет бюджета для «${cat.name}»',
            description: 'Потрачено ${fmt(entry.value)}.',
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
    for (final o in curOps.where((o) => o.type == 'expense' && housingCats.contains(o.categoryId))) {
      housingTotal += _amountInRub(o);
    }
    if (monthIncome > 0 && housingTotal > 0) {
      final housingRatio = housingTotal / monthIncome * 100;
      if (housingRatio > _recPrefs.housingPct) {
          _recommendations.add(Recommendation(
            id: 'high_housing', type: 'risk', severity: 'high',
            title: 'Жильё — ${housingRatio.round()}% от дохода',
            description: 'На жильё уходит ${fmt(housingTotal)} из ${fmt(monthIncome)}.',
            titleArgs: {'pct': housingRatio.round().toString()},
            descArgs: {'amount': fmt(housingTotal), 'income': fmt(monthIncome), 'pct': housingRatio.round().toString(), 'limit': _recPrefs.housingPct.round().toString()},
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
          description: 'Доход ${fmt(monthIncome)}, расходы ${fmt(monthExpense)}.',
          descArgs: {'income': fmt(monthIncome), 'expense': fmt(monthExpense), 'deficit': fmt(monthExpense - monthIncome)},
        ));
      } else if (savingsRate < _recPrefs.savingsLowPct) {
        final saveAmt = monthIncome - monthExpense;
        _recommendations.add(Recommendation(
          id: 'low_savings', type: 'risk', severity: 'medium',
          title: 'Низкая норма сбережения',
          description: 'Откладывается ${fmt(saveAmt)} (${savingsRate.round()}%).',
          descArgs: {'amount': fmt(saveAmt), 'pct': savingsRate.round().toString(), 'income': fmt(monthIncome), 'good_pct': _recPrefs.savingsGoodPct.round().toString(), 'target': fmt(monthIncome * _recPrefs.savingsGoodPct / 100)},
        ));
      } else if (savingsRate >= _recPrefs.savingsGoodPct) {
        final saveAmt = monthIncome - monthExpense;
        _recommendations.add(Recommendation(
          id: 'good_savings', type: 'tip', severity: 'low',
          title: 'Хорошая норма сбережения',
          description: 'Отложено ${fmt(saveAmt)} (${savingsRate.round()}).',
          descArgs: {'amount': fmt(saveAmt), 'pct': savingsRate.round().toString(), 'income': fmt(monthIncome)},
        ));
      }
    }

    // 6 — biggest expense categories
    if (monthExpense > 0) {
      final topCatList = sortedCats.take(5).where((e) {
        final cat = _catById[e.key];
        return cat != null && e.value > monthExpense * _recPrefs.topCatMinPct / 100;
      }).toList();
      if (topCatList.length >= 2) {
        final parts = topCatList.map((e) {
          final cat = _catById[e.key];
          final p = (e.value / monthExpense * 100).round();
          return '${cat?.name ?? e.key} ${fmt(e.value)} ($p%)';
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
      final suggested = monthExpense > 0 ? '${(monthExpense * _recPrefs.emergencyMonths).toStringAsFixed(0)} $sym' : '—';
      _recommendations.add(Recommendation(
        id: 'no_emergency', type: 'tip', severity: 'low',
        title: 'Создайте финансовую подушку',
        description: 'Рекомендуется резерв ${_recPrefs.emergencyMonths.round()}–${(_recPrefs.emergencyMonths * 2).round()} месячных расходов ($suggested).',
        actionType: 'create_goal',
        actionPayload: 'emergency',
        descArgs: {'amount': suggested, 'months': _recPrefs.emergencyMonths.round().toString()},
      ));
    }

    // 8 — idle cash
    for (final a in _accounts) {
      if (a.icon == 'cash' && a.balance > _recPrefs.idleCashMin) {
        _recommendations.add(Recommendation(
          id: 'idle_cash_${a.id}', type: 'optimization', severity: 'low',
          title: '${fmt(a.balance)} наличными без движения',
          description: 'На счету «${a.name}» ${fmt(a.balance)}.',
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
          description: 'Накоплено ${fmt(g.currentAmount)} из ${fmt(g.targetAmount)}.',
          titleArgs: {'title': g.title},
          descArgs: {'current': fmt(g.currentAmount), 'target': fmt(g.targetAmount), 'pct': progress.round().toString(), 'remaining': fmt(g.targetAmount - g.currentAmount)},
        ));
      }
    }

    // 10 — expense trend (spending increased vs previous month)
    if (prevExpense > 0 && monthExpense > 0) {
      final expChange = (monthExpense - prevExpense) / prevExpense * 100;
      if (expChange > _recPrefs.trendUpPct) {
        _recommendations.add(Recommendation(
          id: 'expense_trend_up', type: 'risk', severity: 'medium',
          title: 'Расходы выросли на ${expChange.round()}%',
          description: 'Было ${fmt(prevExpense)}, стало ${fmt(monthExpense)}.',
          titleArgs: {'pct': expChange.round().toString()},
          descArgs: {'pct': expChange.round().toString(), 'prev': fmt(prevExpense), 'curr': fmt(monthExpense)},
        ));
      }
    }

    // 11 — income trend (income dropped vs previous month)
    if (prevIncome > 0 && monthIncome > 0) {
      final incChange = (monthIncome - prevIncome) / prevIncome * 100;
      if (incChange < -_recPrefs.trendUpPct) {
        _recommendations.add(Recommendation(
          id: 'income_trend_down', type: 'risk', severity: 'medium',
          title: 'Доход упал на ${incChange.abs().round()}%',
          description: 'Было ${fmt(prevIncome)}, стало ${fmt(monthIncome)}.',
          titleArgs: {'pct': incChange.abs().round().toString()},
          descArgs: {'pct': incChange.abs().round().toString(), 'prev': fmt(prevIncome), 'curr': fmt(monthIncome)},
        ));
      }
    }

    // 12 — category spike (spending in a category jumped vs its 3-month average)
    final catExpenses = <String, List<double>>{};
    for (int m = 0; m < 4; m++) {
      final ms = DateTime(now.year, now.month - m, 1);
      final me = DateTime(now.year, now.month - m + 1, 0);
      for (final o in _operations.where((o) => o.type == 'expense' && o.categoryId != null && _inPeriod(o.date, ms, me))) {
        catExpenses.putIfAbsent(o.categoryId!, () => []);
        if (m == 0) catExpenses[o.categoryId]!.add(_amountInRub(o));
      }
    }
    for (final entry in catExpenses.entries) {
      final curTotal = entry.value.fold(0.0, (s, v) => s + v);
      final cat3m = _catById[entry.key];
      if (cat3m == null || curTotal < 500) continue;
      final prevTotals = <double>[];
      for (int m = 1; m <= 3; m++) {
        final ms = DateTime(now.year, now.month - m, 1);
        final me = DateTime(now.year, now.month - m + 1, 0);
        double sum = 0;
        for (final o in _operations.where((o) => o.type == 'expense' && o.categoryId == entry.key && _inPeriod(o.date, ms, me))) {
          sum += _amountInRub(o);
        }
        if (sum > 0) prevTotals.add(sum);
      }
      if (prevTotals.isNotEmpty) {
        final avg3m = prevTotals.reduce((a, b) => a + b) / prevTotals.length;
        if (avg3m > 0 && curTotal > avg3m * (1 + _recPrefs.spikePct / 100)) {
          _recommendations.add(Recommendation(
            id: 'category_spike_${entry.key}', type: 'risk', severity: 'medium',
            title: 'Рост «${cat3m.name}» на ${((curTotal - avg3m) / avg3m * 100).round()}%',
            description: 'Было ${fmt(avg3m)}/мес, стало ${fmt(curTotal)}.',
            titleArgs: {'name': cat3m.name, 'pct': ((curTotal - avg3m) / avg3m * 100).round().toString()},
            descArgs: {'name': cat3m.name, 'pct': ((curTotal - avg3m) / avg3m * 100).round().toString(), 'avg': fmt(avg3m), 'curr': fmt(curTotal)},
          ));
        }
      }
    }

    // 13 — recurring expenses (potential subscriptions)
    final catMonthTotals = <String, Map<int, double>>{};
    for (int m = 0; m < _recPrefs.recurringMonths; m++) {
      final ms = DateTime(now.year, now.month - m, 1);
      final me = DateTime(now.year, now.month - m + 1, 0);
      for (final o in _operations.where((o) => o.type == 'expense' && o.categoryId != null && _inPeriod(o.date, ms, me))) {
        catMonthTotals.putIfAbsent(o.categoryId!, () => {});
        catMonthTotals[o.categoryId!]![m] = (catMonthTotals[o.categoryId!]![m] ?? 0) + _amountInRub(o);
      }
    }
    final subCats = <String>{};
    for (final entry in catMonthTotals.entries) {
      if (entry.value.length >= _recPrefs.recurringMonths) {
        final amounts = entry.value.values.toList();
        final avg = amounts.reduce((a, b) => a + b) / amounts.length;
        if (avg > 200 && amounts.every((a) => (a - avg).abs() / avg < 0.15)) {
          subCats.add(entry.key);
        }
      }
    }
    if (subCats.isNotEmpty) {
      final catNames = subCats.map((id) {
        final c = _catById[id];
        return c?.name ?? id;
      }).join(', ');
      final totalSub = subCats.fold(0.0, (s, id) {
        return s + (catMonthTotals[id]?[0] ?? 0);
      });
      _recommendations.add(Recommendation(
        id: 'recurring_subscriptions', type: 'optimization', severity: 'low',
        title: 'Возможные подписки: $catNames',
        description: 'Ежемесячно ~${fmt(totalSub)}. Проверьте, нужны ли они.',
        titleArgs: {'categories': catNames},
        descArgs: {'categories': catNames, 'amount': fmt(totalSub)},
      ));
    }

    // 14 — single category dominance
    if (monthExpense > 0 && sortedCats.isNotEmpty) {
      final top = sortedCats.first;
      final topPct = top.value / monthExpense * 100;
      if (topPct > _recPrefs.singleCatDominancePct) {
        final catName = _catById[top.key]?.name ?? top.key;
        _recommendations.add(Recommendation(
          id: 'dominant_${top.key}', type: 'optimization', severity: 'medium',
          title: '«$catName» — ${topPct.round()}% расходов',
          description: 'Потрачено ${fmt(top.value)} из ${fmt(monthExpense)}.',
          titleArgs: {'name': catName, 'pct': topPct.round().toString()},
          descArgs: {'name': catName, 'pct': topPct.round().toString(), 'amount': fmt(top.value), 'total': fmt(monthExpense)},
        ));
      }
    }

    // 15 — weekend splurge
    if (monthExpense > 0) {
      double weekendExp = 0;
      for (final o in curOps.where((o) => o.type == 'expense')) {
        final d = DateTime.tryParse(o.date);
        if (d != null && (d.weekday == 6 || d.weekday == 7)) weekendExp += _amountInRub(o);
      }
      final weekendPct = weekendExp / monthExpense * 100;
      if (weekendPct > _recPrefs.weekendRatioPct) {
        _recommendations.add(Recommendation(
          id: 'weekend_splurge', type: 'optimization', severity: 'low',
          title: '${weekendPct.round()}% расходов на выходных',
          description: 'Потрачено ${fmt(weekendExp)} за субботу и воскресенье.',
          titleArgs: {'pct': weekendPct.round().toString()},
          descArgs: {'pct': weekendPct.round().toString(), 'amount': fmt(weekendExp)},
        ));
      }
    }

    // 16 — large cash withdrawal
    for (final o in curOps.where((o) => o.type == 'expense')) {
      final convertedAmt = _amountInRub(o);
      if (convertedAmt > _recPrefs.largeCashMin) {
        final cat = _catById[o.categoryId];
        final name = cat?.name ?? 'Без категории';
        _recommendations.add(Recommendation(
          id: 'large_cash_${o.id}', type: 'risk', severity: 'medium',
          title: 'Крупная трата: ${fmt(convertedAmt)}',
          description: '«$name» — ${o.date.substring(0, 10)}.',
          titleArgs: {'amount': fmt(convertedAmt)},
          descArgs: {'amount': fmt(convertedAmt), 'name': name, 'date': o.date.substring(0, 10)},
        ));
      }
    }

    // 17 — goal pacing (will goal be met on time?)
    final savingsRate = monthIncome > 0 ? (monthIncome - monthExpense) / monthIncome : 0.0;
    for (final g in _goals.where((g) => !g.isCompleted && g.targetAmount > 0 && g.deadline.isNotEmpty)) {
      final remaining = g.targetAmount - g.currentAmount;
      if (remaining <= 0) continue;
      final deadline = DateTime.tryParse(g.deadline);
      if (deadline == null) continue;
      final monthsLeft = (deadline.difference(now).inDays / 30).ceil();
      if (monthsLeft <= 0) {
        _recommendations.add(Recommendation(
          id: 'goal_pacing_expired', type: 'risk', severity: 'high',
          title: 'Цель «${g.title}» просрочена',
          description: 'Осталось ${fmt(remaining)}, дедлайн ${deadline.day}.${deadline.month}.${deadline.year}.',
          titleArgs: {'title': g.title},
          descArgs: {'remaining': fmt(remaining), 'deadline': '${deadline.day}.${deadline.month}.${deadline.year}'},
        ));
      } else if (monthIncome > 0) {
        final monthlyNeeded = remaining / monthsLeft;
        final monthlyCanSave = monthIncome * savingsRate;
        if (monthlyCanSave > 0 && monthlyNeeded > monthlyCanSave * 1.5) {
          _recommendations.add(Recommendation(
            id: 'goal_pacing_slow', type: 'optimization', severity: 'medium',
            title: 'Цель «${g.title}» отстаёт',
            description: 'Нужно ${fmt(monthlyNeeded)}/мес, откладываете ${fmt(monthlyCanSave)}/мес.',
            titleArgs: {'title': g.title},
            descArgs: {'needed': fmt(monthlyNeeded), 'current': fmt(monthlyCanSave), 'deadline': '${deadline.day}.${deadline.month}.${deadline.year}'},
          ));
        }
      }
    }

    // fallback
    if (_recommendations.isEmpty) {
      _recommendations.add(Recommendation(
        id: 'all_good', type: 'tip', severity: 'low',
        title: 'Всё в порядке!',
        description: 'Сейчас нет рекомендаций. Добавляйте операции и ставьте цели.',
      ));
    }
  }

  Map<String, dynamic> _buildOperationPayload(Operation op, {String? existingId, String? createdAt, String? updatedAt, String? deletedAt}) {
    final now = DateTime.now();
    final operationDate = DateTime.tryParse(op.date) ?? now;
    final dateStr = formatApiDateTime(operationDate);
    final timeStr = '${operationDate.hour.toString().padLeft(2, '0')}:${operationDate.minute.toString().padLeft(2, '0')}:${operationDate.second.toString().padLeft(2, '0')}';
    final created = createdAt ?? formatApiDateTime(now);
    final updated = updatedAt ?? formatApiDateTime(now);
    final amount = op.type == 'income' ? op.amount : -op.amount;
    final transferAmt = op.transferAmount ?? op.amount;
    final stableClientId = op.clientId ?? op.id;
    final clientIdNum = int.tryParse(stableClientId) ?? stableClientId.hashCode.abs();
    return {
      if (existingId != null) 'id': existingId,
      'type': _typeToApi(op.type),
      'user_id': apiClient.userId ?? '',
      'account_id': op.accountId,
      if (op.categoryId != null) 'category_id': op.categoryId,
      if (op.categoryId == null && op.type == 'transfer') 'category_id': _transferCategoryId(),
      'currency_id': _currencyIdForAccount(op.accountId),
      'amount': amount.toStringAsFixed(2),
      'date': dateStr,
      'time': timeStr,
      if (op.toAccountId != null) 'transfer_account_id': op.toAccountId,
      if (op.toAccountId != null) 'transfer_amount': transferAmt.toStringAsFixed(2),
      if (op.comment != null) 'comment': op.comment,
      if (op.tags != null) 'tags': op.tags,
      'accepted': true,
      if (existingId == null) 'client_id': clientIdNum,
      if (deletedAt != null) 'state': '2',
      'created_at': created,
      'updated_at': updated,
      'deleted_at': deletedAt,
    };
  }

  Future<void> addOperation(Operation op) async {
    _error = null;
    // Лимит в 1000 операций распространяется только на бесплатный тариф.
    // У пользователей с активным платным тарифом (isPremium) этого ограничения нет.
    final isFreeUser = _currentUser == null || !_currentUser!.isPremium;
    if (isFreeUser && _operations.length >= 1000) {
      _error = 'LIMIT';
      _scheduleNotify();
      return;
    }
    final clientId = op.clientId ?? op.id;
    op = op.copyWith(clientId: clientId);
    if (authService.isAuthenticated) {
      try {
        final now = DateTime.now();
        final payload = _buildOperationPayload(op, createdAt: formatApiDateTime(now), updatedAt: formatApiDateTime(now));
        final response = await authService.apiService.addOperation({'operations': [payload]});
        final serverOperations = response['operations'] as List<dynamic>?;
        final serverId = serverOperations?.isNotEmpty == true
            ? (serverOperations!.first as Map<String, dynamic>)['id']?.toString()
            : null;
        if (serverId == null || serverId.isEmpty) {
          throw ApiException('Сервер не вернул ID операции', 'MISSING_OPERATION_ID');
        }
        op = op.copyWith(id: serverId, isPending: false, clientId: clientId);
      } on ApiException catch (e) {
        final msg = e.message.toLowerCase();
        final isNetwork = msg.contains('timeout') || msg.contains('socket') || msg.contains('network') || msg.contains('connection') || e.code == 'TIMEOUT' || e.code == 'NETWORK';
        if (isNetwork) {
          op = op.copyWith(isPending: true, clientId: clientId);
        } else {
          _error = e.message;
          _scheduleNotify();
          return;
        }
      } catch (_) {
        op = op.copyWith(isPending: true, clientId: clientId);
      }
    } else {
      op = op.copyWith(isPending: true, clientId: clientId);
    }
    op = op.copyWith(updatedAt: formatApiDateTime());
    _operations.insert(0, op);
    _invalidateOpCaches();
    _changedOpIds.add(op.id);
    _recalcBudgetSpent();
    _scheduleRecommendations();
    await _registerTags(op.tags);
    await _saveCache();
    if (_rates.isNotEmpty) {
      final opDate = DateTime.tryParse(op.date) ?? DateTime.now();
      await RateHistoryStorage.saveRates(opDate, _rates);
    }
    _scheduleNotify();
  }

  String _typeToApi(String type) {
    switch (type) {
      case 'expense': return '0';
      case 'income': return '1';
      case 'transfer': return '2';

      default: return '0';
    }
  }

  String? _transferCategoryId() {
    return _categories.cast<cat.Category?>().firstWhere((c) => c!.type == '0' && (c.name == 'Перевод' || c.name == 'Transfer' || c.name.contains('еревод') || c.name.toLowerCase().contains('transfer')), orElse: () => null)?.id;
  }

  /// Re-fetches the operation list from the server. Used after an operation is
  /// created or accepted elsewhere (e.g. confirming a planned payment) so the
  /// ledger reflects it immediately without a manual pull-to-refresh.
  Future<void> reloadOperations() async {
    if (!authService.isAuthenticated) return;
    final pending = _operations.where((op) => op.isPending).toList();
    try {
      _operations = await authService.apiService.getOperations();
      _opsDirty = true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error ??= 'Ошибка загрузки операций: $e';
    }
    final serverIds = _operations.map((o) => o.id).toSet();
    for (final p in pending) {
      if (!serverIds.contains(p.id)) _operations.insert(0, p);
    }
    _scheduleNotify();
  }

  Future<void> syncPendingOperations() async {
    if (!authService.isAuthenticated) return;
    final pending = _operations.where((op) => op.isPending).toList();
    if (pending.isEmpty) return;
    for (final op in pending) {
      try {
        final withClient = op.copyWith(clientId: op.clientId ?? op.id);
        final now = DateTime.now();
        final isDel = op.isDeleted;
        final payload = _buildOperationPayload(
          withClient,
          createdAt: formatApiDateTime(now),
          updatedAt: formatApiDateTime(now),
          deletedAt: isDel ? formatApiDateTime(now) : null,
        );
        final response = await authService.apiService.addOperation({'operations': [payload]});
        final serverOperations = response['operations'] as List<dynamic>?;
        final serverId = serverOperations?.isNotEmpty == true
            ? (serverOperations!.first as Map<String, dynamic>)['id']?.toString()
            : null;
        final idx = _operations.indexWhere((o) => o.id == op.id);
        if (idx >= 0) {
          if (isDel) {
            _operations.removeAt(idx);
            _opsDirty = true;
          } else if (serverId != null && serverId.isNotEmpty) {
            _operations[idx] = _operations[idx].copyWith(id: serverId, isPending: false, clientId: withClient.clientId);
          }
        }
      } catch (e) {
        debugPrint('Sync pending op ${op.id} failed: $e');
      }
    }
    _recalcBudgetSpent();
    _scheduleRecommendations();
    _scheduleNotify();
  }

  bool _isNetworkError(ApiException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('timeout') || msg.contains('socket') || msg.contains('network') || msg.contains('connection') || e.code == 'TIMEOUT' || e.code == 'NETWORK';
  }

  Future<void> updateOperation(Operation op) async {
    _error = null;
    if (authService.isAuthenticated && !op.isPending) {
      try {
        final now = DateTime.now();
        final operationDate = DateTime.tryParse(op.date) ?? now;
        final dateStr = formatApiDateTime(operationDate);
        final timeStr = '${operationDate.hour.toString().padLeft(2, '0')}:${operationDate.minute.toString().padLeft(2, '0')}:${operationDate.second.toString().padLeft(2, '0')}';
        final updatedAt = formatApiDateTime(now);
        final amount = op.type == 'income' ? op.amount : -op.amount;

        await authService.apiService.setOperation({
          'operations': [{
            'id': op.id,
            'type': _typeToApi(op.type),
            'account_id': op.accountId,
            if (op.categoryId != null) 'category_id': op.categoryId,
            if (op.categoryId == null && op.type == 'transfer') 'category_id': _transferCategoryId(),
            'currency_id': _currencyIdForAccount(op.accountId),
            'amount': amount.toStringAsFixed(2),
            'date': dateStr,
            'time': timeStr,
            if (op.toAccountId != null) 'transfer_account_id': op.toAccountId,
            if (op.toAccountId != null) 'transfer_amount': (op.transferAmount ?? op.amount).toStringAsFixed(2),
            if (op.comment != null) 'comment': op.comment,
            if (op.tags != null) 'tags': op.tags,
            'accepted': true,
            'updated_at': updatedAt,
            'deleted_at': null,
          }]
        }, operationId: op.id);
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
      _operations[idx] = op.copyWith(updatedAt: formatApiDateTime());
    }
    _invalidateOpCaches();
    _changedOpIds.add(op.id);

    _recalcBudgetSpent();
    _scheduleRecommendations();
    await _registerTags(op.tags);
    await _saveCache();
    _scheduleNotify();
  }

  Future<void> deleteOperation(String id) async {
    _error = null;
    final opIdx = _operations.indexWhere((o) => o.id == id);
    if (opIdx < 0) return;
    final op = _operations[opIdx];
    if (op.isPending) {
      _operations.removeAt(opIdx);
      _invalidateOpCaches();
      _deletedOpIds.add(id);
    _recalcBudgetSpent();
    _scheduleRecommendations();
    _scheduleNotify();
      return;
    }
    if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        final payload = _buildOperationPayload(op, existingId: op.id, updatedAt: now, deletedAt: now);
        await authService.apiService.setOperation({'operations': [payload]}, operationId: op.id);
      } on ApiException catch (e) {
        if (_isNetworkError(e)) {
          _queuePendingDelete(op, opIdx);
          return;
        }
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('socket') || msg.contains('host') || msg.contains('network') || msg.contains('connection')) {
          _queuePendingDelete(op, opIdx);
          return;
        }
        _error = 'Ошибка удаления: $e'; notifyListeners();
        return;
      }
    }
    if (!op.isDeleted) {
      _operations[opIdx] = _operations[opIdx].copyWith(isDeleted: true);
    }
    _invalidateOpCaches();
    _changedOpIds.add(op.id);

    _recalcBudgetSpent();
    _scheduleRecommendations();
    await _saveCache();
    _scheduleNotify();
  }

  void _queuePendingDelete(Operation op, int idx) {
    final now = formatApiDateTime();
    _operations[idx] = op.copyWith(isPending: true, isDeleted: true, updatedAt: now);

    _recalcBudgetSpent();
    _scheduleRecommendations();
    _saveCache();
    _scheduleNotify();
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

   Future<void> addAccount(Account account, {String state = '0'}) async {
    _error = null;
    Account toAdd = account;
    if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        final newAccount = account.copyWith();
        final resp = await authService.apiService.addAccount({
          'accounts': [{
            'name': account.name,
            'init_balance': (account.initBalance > 0 ? account.initBalance : account.balance).toStringAsFixed(2),
            'type_id': _accountTypeToApi(account.type),
            'state': state,
            if (account.currencyId != null) 'currency_id': account.currencyId else 'currency_id': '1',
            'icon': _accountIconToApi(account.icon),
            'include_in_total': account.includeInTotal ? '1' : '0',
            'created_at': now,
            'updated_at': now,
            ..._creditFields(account),
          }]
        });
        final accounts = resp['accounts'] as List<dynamic>?;
        if (accounts != null && accounts.isNotEmpty) {
          final serverId = accounts[0]['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            _accounts.add(newAccount.copyWith(id: serverId));
            await _saveCache();
            _scheduleNotify();
            return;
          }
        }
        throw ApiException('Сервер не вернул ID счёта', 'MISSING_ACCOUNT_ID');
      } on ApiException catch (e) {
        if (_isNetworkError(e)) {
          toAdd = account.copyWith(isPending: true);
        } else {
          _error = e.message; notifyListeners();
          return;
        }
      } catch (e) {
        toAdd = account.copyWith(isPending: true);
      }
    } else {
      toAdd = account;
    }
    _accounts.add(toAdd);
    _accountById[toAdd.id] = toAdd;
    await _saveCache();
    _scheduleNotify();
  }

  Future<void> updateAccount(Account account, {String state = '0'}) async {
    _error = null;
    var acc = account;
    if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        await authService.apiService.setAccount({
          'accounts': [{
            'id': account.id,
            'name': account.name,
            'init_balance': account.initBalance.toStringAsFixed(2),
            'type_id': _accountTypeToApi(account.type),
            'state': state,
            if (account.currencyId != null) 'currency_id': account.currencyId else 'currency_id': '1',
            'icon': _accountIconToApi(account.icon),
            'include_in_total': account.includeInTotal ? '1' : '0',
            'updated_at': now,
            ..._creditFields(account),
          }]
        }, accountId: account.id);
      } on ApiException catch (e) {
        if (_isNetworkError(e)) {
          acc = account.copyWith(isPending: true);
        } else {
          _error = e.message; notifyListeners();
          return;
        }
      } catch (e) {
        acc = account.copyWith(isPending: true);
      }
    } else {
      acc = account;
    }
    final idx = _accounts.indexWhere((a) => a.id == acc.id);
    if (idx >= 0) _accounts[idx] = acc; else _accounts.add(acc);
    _accountById[acc.id] = acc;

    await _saveCache();
    _scheduleNotify();
  }

  void updateAccountFavorite(String accountId, bool isFavorite) async {
    final idx = _accounts.indexWhere((a) => a.id == accountId);
    if (idx < 0) return;
    _accounts[idx] = _accounts[idx].copyWith(isFavorite: isFavorite);
    _saveCache();
    _scheduleNotify();
    if (authService.isAuthenticated) {
      try {
        await authService.apiService.setAccount({
          'accounts': [{
            'id': accountId,
            'state': isFavorite ? '1' : '0',
            'updated_at': formatApiDateTime(),
          }]
        }, accountId: accountId);
      } catch (_) {}
    }
  }

  Future<void> deleteAccount(String id) async {
    _error = null;
    if (authService.isAuthenticated) {
      try {
        final account = _accounts.where((a) => a.id == id).firstOrNull;
        if (account == null) {
          _error = 'Счёт не найден';
          _scheduleNotify();
          return;
        }
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
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
        return;
      } catch (e) {
        _error = 'Ошибка удаления счёта: $e'; notifyListeners();
        return;
      }
    }
    _accounts.removeWhere((a) => a.id == id);
    _accountById.remove(id);
    await _saveCache();
    _scheduleNotify();
  }

  // --- Categories ---

  /// Maps a category's `catimgN` icon to its server `system_id`, built from
  /// the system categories returned by `categories.get`.
  Map<String, String> _systemIconToId = {};

  void _buildSystemIconMap(List<Map<String, dynamic>> rawCats) {
    final map = <String, String>{};
    for (final j in rawCats) {
      final sid = j['system_id']?.toString();
      final iconKey = j['icon']?.toString() ?? '';
      if (sid != null && sid.isNotEmpty && iconKey.startsWith('catimg')) {
        map.putIfAbsent(iconKey, () => sid);
      }
    }
    _systemIconToId = map;
  }

  String _systemIdForLogical(String logical) {
    final catimg = _categoryIconToApi(logical);
    return _systemIconToId[catimg]
        ?? (logical == 'income' || logical == 'other_income' ? '9' : '1');
  }

  Future<void> addCategory(cat.Category c) async {
    _error = null;
    cat.Category toAdd = c;
    if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        final typeCode = c.type == 'expense' ? '-1' : '1';
        final record = {
          'name': c.name,
          'type': typeCode,
          'icon': _categoryIconToApi(c.icon),
          'system_id': c.systemId?.isNotEmpty == true ? c.systemId! : _systemIdForLogical(c.icon),
          'custom': '1',
          'parent_id': c.parentId ?? '0',
          'is_hidden': '0',
          'created_at': now,
          'updated_at': now,
        };
        final data = await apiClient.postCategoryV2(record);
        final categories = data['categories'] as List<dynamic>?;
        if (categories != null && categories.isNotEmpty) {
          final serverId = categories[0]['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            final sid = c.systemId?.isNotEmpty == true ? c.systemId! : _systemIdForLogical(c.icon);
            _categories.add(cat.Category(
              id: serverId, name: c.name, type: c.type, icon: c.icon, color: c.color,
              parentId: c.parentId, isDefault: false, systemId: sid,
            ));
            await _saveCache();
            _scheduleNotify();
            return;
          }
        }
        throw ApiException('Сервер не вернул ID категории', 'MISSING_CATEGORY_ID');
      } on ApiException catch (e) {
        if (_isNetworkError(e)) {
          toAdd = c.copyWith(isPending: true);
        } else {
          _error = e.message; notifyListeners();
          return;
        }
      } catch (e) {
        toAdd = c.copyWith(isPending: true);
      }
    } else {
      toAdd = c;
    }
    _categories.add(toAdd);
    _catById[toAdd.id] = toAdd;
    await _saveCache();
    _scheduleNotify();
  }

  Future<void> updateCategory(cat.Category c) async {
    _error = null;
    var catToSave = c;
    if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        final typeCode = c.type == 'expense' ? '-1' : '1';
        final record = {
          'id': c.id,
          'name': c.name,
          'type': typeCode,
          'icon': _categoryIconToApi(c.icon),
          'system_id': c.systemId?.isNotEmpty == true ? c.systemId! : _systemIdForLogical(c.icon),
          'custom': c.isDefault ? '0' : '1',
          'parent_id': c.parentId ?? '0',
          'is_hidden': '0',
          'created_at': now,
          'updated_at': now,
        };
        await apiClient.setCategoryV2(c.id, record);
      } on ApiException catch (e) {
        if (_isNetworkError(e)) {
          catToSave = c.copyWith(isPending: true);
        } else {
          _error = e.message; notifyListeners();
          return;
        }
      } catch (e) {
        catToSave = c.copyWith(isPending: true);
      }
    } else {
      catToSave = c;
    }
    final idx = _categories.indexWhere((x) => x.id == catToSave.id);
    if (idx >= 0) _categories[idx] = catToSave; else _categories.add(catToSave);
    _catById[catToSave.id] = catToSave;
    await _saveCache();
    _scheduleNotify();
  }

  Future<void> deleteCategory(String id) async {
    _error = null;
    final idx = _categories.indexWhere((x) => x.id == id);
    if (idx < 0) return;
    final c = _categories[idx];
    // Local-only (pending) categories are removed locally only.
    if (c.isPending) {
      _categories.removeAt(idx);
      _catById.remove(id);
      await _saveCache();
      _scheduleNotify();
      return;
    }
    // Server-backed categories: delete on the server FIRST (mirrors
    // deleteOperation). Only remove locally after a successful response, so a
    // server rejection keeps the category visible instead of resurrecting it on
    // the next fetch. We send the full record with `deleted_at` set, exactly
    // like updateCategory, so the API soft-deletes it.
    if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        final typeCode = c.type == 'expense' ? '-1' : '1';
        final record = {
          'id': c.id,
          'name': c.name,
          'type': typeCode,
          'icon': _categoryIconToApi(c.icon),
          'system_id': c.systemId?.isNotEmpty == true ? c.systemId! : _systemIdForLogical(c.icon),
          'custom': c.isDefault ? '0' : '1',
          'parent_id': c.parentId ?? '0',
          'is_hidden': '0',
          'created_at': now,
          'updated_at': now,
          'deleted_at': now,
        };
        await apiClient.setCategoryV2(c.id, record);
      } on ApiException catch (e) {
        _error = e.message;
        _scheduleNotify();
        return;
      } catch (e) {
        _error = 'Ошибка удаления категории: $e';
        _scheduleNotify();
        return;
      }
    }
    _categories.removeWhere((x) => x.id == id);
    _catById.remove(id);
    await _saveCache();
    _scheduleNotify();
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

  String _accountTypeToApi(String type) => accountTypeToId(type);

  String _accountIconToApi(String icon) {
    const map = <String, String>{
      'cash': 'accountimage1', 'credit_card': 'accountimage2',
      'savings': 'accountimage3', 'account_balance': 'accountimage4',
      'wallet': 'accountimage5', 'payments': 'accountimage6',
      'currency_ruble': 'accountimage7', 'card_giftcard': 'accountimage8',
    };
    return map[icon] ?? 'accountimage1';
  }

  /// Returns a map of credit-specific fields for the API request,
  /// only when the account type is credit/credit_card.
  Map<String, String> _creditFields(Account account) {
    final fields = <String, String>{};
    if (account.description != null && account.description!.isNotEmpty) {
      fields['description'] = account.description!;
    }
    if (account.bankId != null) fields['bank_id'] = account.bankId!;
    if (account.annualRate != null) fields['annual_rate'] = account.annualRate!.toStringAsFixed(2);
    if (account.paymentType != null) fields['payment_type'] = account.paymentType!;
    if (account.openDate != null) fields['open_date'] = account.openDate!;
    if (account.closeDate != null) fields['close_date'] = account.closeDate!;
    if (account.commissionOneTime != null) fields['commission_one_time'] = account.commissionOneTime!.toStringAsFixed(2);
    if (account.commissionMonthly != null) fields['commission_monthly'] = account.commissionMonthly!.toStringAsFixed(2);
    if (account.paymentDay != null) fields['payment_day'] = account.paymentDay!.toString();
    if (account.creditLimit != null) fields['credit_limit'] = account.creditLimit!.toStringAsFixed(2);
    return fields;
  }

  Future<void> addBudget(Budget b) async {
    _error = null;
    final spent = _calcSpentForMonth(b.categoryId);
    if (authService.isAuthenticated) {
      try {
        final resp = await authService.apiService.addBudgetCategory({
          'budgets': [{
            'category_id': b.categoryId,
            'planned': b.limit.toStringAsFixed(2),
          }]
        });
        final budgets = resp['budgets'] as List<dynamic>?;
        final serverId = budgets != null && budgets.isNotEmpty ? budgets[0]['id']?.toString() : null;
        _budgets.add(Budget(
          id: (serverId != null && serverId.isNotEmpty) ? serverId : b.id,
          name: b.name, categoryId: b.categoryId,
          limit: b.limit, spent: spent, period: b.period,
        ));
        await _saveBudgets();
        _scheduleRecommendations();
        _scheduleNotify();
        return;
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
    _scheduleRecommendations();
    _scheduleNotify();
  }

  Future<void> updateBudget(Budget b) async {
    _error = null;
    if (authService.isAuthenticated) {
      try {
        await authService.apiService.setBudgetCategory({
          'budgets': [{
            'id': b.id,
            'planned': b.limit.toStringAsFixed(2),
          }]
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
    _scheduleNotify();
  }

  double _calcSpentForMonth(String categoryId) {
    final now = DateTime.now();
    final ops = _operations.where((o) {
      if (o.categoryId != categoryId || o.type != 'expense' || o.isDeleted) return false;
      final dateKey = o.date.length >= 10 ? o.date.substring(0, 10) : o.date;
      final d = DateTime.tryParse(dateKey);
      return d != null && d.year == now.year && d.month == now.month;
    });
    return ops.fold(0.0, (sum, o) => sum + o.amount);
  }

  void _recalcBudgetSpent() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final catSpent = <String, double>{};
    for (final o in _operations) {
      if (o.isDeleted || o.type != 'expense' || o.categoryId == null) continue;
      if (_inPeriod(o.date, start, end)) {
        catSpent[o.categoryId!] = (catSpent[o.categoryId!] ?? 0) + o.amount;
      }
    }
    for (var i = 0; i < _budgets.length; i++) {
      final b = _budgets[i];
      if (b.isDeleted) continue;
      final spent = catSpent[b.categoryId] ?? 0.0;
      if ((spent - b.spent).abs() > 0.01) {
        _budgets[i] = b.copyWith(spent: spent);
      }
    }
  }

  Map<String, double> _ratesForOp(Operation op) {
    final dateKey = op.date.length >= 10 ? op.date.substring(0, 10) : null;
    if (dateKey != null && _histRates.containsKey(dateKey)) {
      return _histRates[dateKey]!;
    }
    return _rates;
  }

  void _recalcAccountBalances() {
    if (!_allOperationsLoaded) return;
    final balances = <String, double>{};
    for (final a in _accounts) {
      balances[a.id] = a.initBalance;
    }
    for (final op in _operations) {
      if (op.isDeleted) continue;
      if (op.type == 'expense') {
        balances[op.accountId] = (balances[op.accountId] ?? 0) - op.amount;
      } else if (op.type == 'income') {
        balances[op.accountId] = (balances[op.accountId] ?? 0) + op.amount;
      } else if (op.type == 'transfer') {
        balances[op.accountId] = (balances[op.accountId] ?? 0) - op.amount;
        final toId = op.toAccountId;
        if (toId != null) {
          final dstCurrency = _accountById[toId]?.currency;
          final srcCurrency = _accountById[op.accountId]?.currency;
          if (op.transferAmount != null && op.transferAmount! > 0) {
            balances[toId] = (balances[toId] ?? 0) + op.transferAmount!;
          } else if (dstCurrency != null && srcCurrency != null && srcCurrency != dstCurrency) {
            final converted = CurrencyRateService.convert(op.amount, srcCurrency, dstCurrency, _ratesForOp(op));
            balances[toId] = (balances[toId] ?? 0) + converted;
          } else {
            balances[toId] = (balances[toId] ?? 0) + op.amount;
          }
        }
      }
    }
    for (var i = 0; i < _accounts.length; i++) {
      final a = _accounts[i];
      final balance = balances[a.id] ?? a.initBalance;
      if ((balance - a.balance).abs() > 0.01) {
        _accounts[i] = a.copyWith(balance: balance);
      }
    }
    _recalcCachedTotals();
  }

  void _recalcCachedTotals() {
    _cachedTotalBalance = _accounts
        .where((a) => a.includeInTotal && !a.isArchived)
        .fold<double>(0, (sum, a) => sum + CurrencyRateService.convert(accountActualBalance(a), a.currency, 'RUB', _rates));
    _cachedMoneyBalance = _accounts
        .where((a) => a.includeInTotal && !a.isArchived && groupForType(a.type) == 'money')
        .fold<double>(0, (sum, a) => sum + CurrencyRateService.convert(accountActualBalance(a), a.currency, 'RUB', _rates));
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _cachedMonthIncome = _operations
        .where((o) => o.type == 'income' && !o.isDeleted && _inPeriod(o.date, start, end))
        .fold(0.0, (s, o) => s + _amountInRub(o));
    _cachedMonthExpense = _operations
        .where((o) => o.type == 'expense' && !o.isDeleted && _inPeriod(o.date, start, end))
        .fold(0.0, (s, o) => s + _amountInRub(o));
  }

  String _iso8601Date(DateTime dt) {
    final tz = dt.timeZoneOffset;
    final sign = tz.isNegative ? '-' : '+';
    final hours = tz.inHours.abs().toString().padLeft(2, '0');
    final minutes = (tz.inMinutes % 60).abs().toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T00:00:00$sign$hours:$minutes';
  }

  Future<void> deleteBudget(String id) async {
    _error = null;
    if (authService.isAuthenticated) {
      try {
        await authService.apiService.setBudgetCategory({
          'budgets': [{'id': id, 'deleted_at': formatApiDateTime()}]
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
    _scheduleRecommendations();
    _scheduleNotify();
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
            id: m['id']?.toString() ?? '',
            name: m['name']?.toString(),
            categoryId: m['categoryId']?.toString() ?? '',
            limit: (m['limit'] as num?)?.toDouble() ?? 0,
            spent: (m['spent'] as num?)?.toDouble() ?? 0,
            period: m['period']?.toString() ?? 'monthly',
            isDeleted: m['isDeleted'] == true,
          );
        }).where((b) => b.id.isNotEmpty).toList();
      }
    } catch (_) {
      _budgets = [];
    }
  }

  String _currencyIdForAccount(String accountId) {
    return _accounts.firstWhere((a) => a.id == accountId, orElse: () => Account(id: '', name: '', balance: 0)).currencyId ?? '1';
  }

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

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
          if (g.accountIds.isNotEmpty) 'accounts': g.accountIds,
          if (g.goalType != null) 'type': g.goalType.toString(),
          if (g.category != null && int.tryParse(g.category!) != null) 'category_id': g.category,
          if (g.goalState != null) 'state': g.goalState.toString(),
          if (g.comment != null && g.comment!.isNotEmpty) 'comment': g.comment,
        });
        final targets = resp['targets'] as List<dynamic>?;
        if (targets != null && targets.isNotEmpty) {
          final serverId = targets[0]['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            _goals.add(Goal(
              id: serverId, title: g.title, targetAmount: g.targetAmount,
              currentAmount: g.currentAmount, startDate: g.startDate.isNotEmpty ? g.startDate : _todayDate(), deadline: g.deadline, icon: g.icon, color: g.color,
              isCompleted: g.isCompleted, accountId: g.accountId, accountIds: g.accountIds,
            ));
            await _saveGoals();
            _scheduleNotify();
            return;
          }
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
              currentAmount: g.currentAmount, deadline: g.deadline, startDate: g.startDate,
              icon: g.icon, color: g.color,               isCompleted: g.isCompleted, accountId: g.accountId, accountIds: g.accountIds,
              currencyId: g.currencyId, comment: g.comment, category: g.category,
              goalType: g.goalType, goalState: g.goalState,
            ));
            await _saveGoals();
            _scheduleNotify();
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
    _scheduleNotify();
  }

  Future<void> updateGoal(String id, {double? currentAmount, bool? isCompleted, String? title, double? targetAmount, String? deadline, String? startDate, String? accountId, List<String>? accountIds, String? currencyId, String? comment, String? category, int? goalType, int? goalState}) async {
    _error = null;
    final idx = _goals.indexWhere((g) => g.id == id);
    if (idx < 0) return;
    final g = _goals[idx];
    final newTitle = title ?? g.title;
    final newTarget = targetAmount ?? g.targetAmount;
    final newDeadline = deadline ?? g.deadline;
    final newStartDate = startDate ?? g.startDate;
    final newAccountId = accountId ?? g.accountId;
    final newAccountIds = accountIds ?? g.accountIds;
    final newCurrencyId = currencyId ?? g.currencyId;
    final newCategory = category ?? g.category;
    final newComment = comment ?? g.comment;
    final newType = goalType ?? g.goalType;
    final newState = goalState ?? g.goalState;

    if (authService.isAuthenticated) {
      try {
        await authService.apiService.setTarget({
          'title': newTitle,
          'amount': newTarget.toStringAsFixed(2),
          'amount_done': (currentAmount ?? g.currentAmount).toStringAsFixed(2),
          'visible': '1',
          'currency_id': newCurrencyId ?? '1',
          if (newStartDate.isNotEmpty) 'date_begin': newStartDate,
          if (newDeadline.isNotEmpty) 'date_end': newDeadline,
          if (newAccountId != null) 'account_id': newAccountId,
          if (newAccountIds.isNotEmpty) 'accounts': newAccountIds,
          if (newType != null) 'type': newType.toString(),
          if (newCategory != null && int.tryParse(newCategory) != null) 'category_id': newCategory,
          if (newState != null) 'state': newState.toString(),
          if (newComment != null && newComment.isNotEmpty) 'comment': newComment,
        }, targetId: id);
        _goals[idx] = g.copyWith(currentAmount: currentAmount, isCompleted: isCompleted, title: newTitle, targetAmount: newTarget, deadline: newDeadline, startDate: newStartDate, accountId: newAccountId, accountIds: newAccountIds, currencyId: newCurrencyId, comment: newComment, category: newCategory, goalType: newType, goalState: newState);
        await _saveGoals();
        _scheduleNotify();
        return;
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка обновления цели: $e'; notifyListeners();
      }
    }

    if (authService.isAuthenticated) {
      try {
        final api = authService.apiService;
        final now = formatApiDateTime();
        await api.setGoalTemplate({
          'operationPatterns': [{
            'id': id,
            'name': newTitle,
            'type': '4',
            'amount': newTarget.toStringAsFixed(2),
            if (newAccountId != null) 'account_id': newAccountId,
            'updated_at': now,
          }]
        }, id: id);
        _error = null;
        _goals[idx] = g.copyWith(currentAmount: currentAmount, isCompleted: isCompleted, title: newTitle, targetAmount: newTarget, deadline: newDeadline, startDate: newStartDate, accountId: newAccountId, accountIds: newAccountIds, currencyId: newCurrencyId, comment: newComment, category: newCategory, goalType: newType, goalState: newState);
        await _saveGoals();
        _scheduleNotify();
        return;
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка обновления цели: $e'; notifyListeners();
      }
    }

    if (authService.isAuthenticated) return;
    _goals[idx] = g.copyWith(currentAmount: currentAmount, isCompleted: isCompleted, title: newTitle, targetAmount: newTarget, deadline: newDeadline, startDate: newStartDate, accountId: newAccountId, accountIds: newAccountIds, currencyId: newCurrencyId, comment: newComment, category: newCategory, goalType: newType, goalState: newState);
    await _saveGoals();
    _scheduleNotify();
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

    final now = formatApiDateTime();
    final clientId = DateTime.now().microsecondsSinceEpoch.toString();
    final goalAccountId = goal.accountId ?? goal.transferAccountId;

    if (goalAccountId != null && goalAccountId.isNotEmpty && goalAccountId != accountId) {
      final src = getAccount(accountId);
      final dst = getAccount(goalAccountId);
      double? transferAmt;
      if (src != null && dst != null && src.currency != dst.currency) {
        transferAmt = CurrencyRateService.convert(amount, src.currency, dst.currency, _rates);
      }
      await addOperation(Operation(
        id: clientId,
        type: 'transfer',
        amount: amount,
        transferAmount: transferAmt,
        date: now,
        accountId: accountId,
        toAccountId: goalAccountId,
        comment: goal.title,
        clientId: clientId,
      ));
    } else {
      final goalCategoryId = _categories
          .where((c) =>
              c.name == 'Инвестиционный расход' ||
              c.name.contains('Инвестицион') ||
              c.name.toLowerCase().contains('invest'))
          .firstOrNull
          ?.id;
      final categoryId = goalCategoryId ??
          _categories
              .where((c) => c.type == 'expense' || c.type == '0')
              .firstOrNull
              ?.id;
      await addOperation(Operation(
        id: clientId,
        type: 'expense',
        amount: amount,
        date: now,
        accountId: accountId,
        categoryId: categoryId,
        comment: goal.title,
        clientId: clientId,
      ));
    }
    if (_error != null) {
      final operationError = _error;
      await updateGoal(goalId, currentAmount: previousAmount, isCompleted: previousCompleted);
      _error = operationError;
      _scheduleNotify();
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
        _scheduleNotify();
        return;
      } on ApiException catch (e) {
        _error = e.message; notifyListeners();
      } catch (e) {
        _error = 'Ошибка удаления цели: $e'; notifyListeners();
      }
    }

    if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        await authService.apiService.setGoalTemplate({
          'operationPatterns': [{'id': id, 'deleted_at': now}]
        }, id: id);
        _error = null;
        _goals.removeWhere((g) => g.id == id);
        await _saveGoals();
        _scheduleNotify();
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
    _scheduleNotify();
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
    var toAdd = t;
    if (authService.isAuthenticated) {
      try {
        final now = formatApiDateTime();
        final typeCode = t.type == 'expense' ? 0 : t.type == 'income' ? 1 : 2;
        final clientId = DateTime.now().millisecondsSinceEpoch.toString();
        final userId = authService.userId ?? '';
        final catIcon = t.categoryId != null ? categories.where((c) => c.id == t.categoryId).firstOrNull?.icon : null;
        final iconCode = catIcon ?? 'catimg1';
        final resp = await authService.apiService.addTemplate({
          'operationPatterns': [{
            'client_id': clientId,
            'user_id': userId,
            'name': t.name,
            'type': typeCode,
            'icon': {'code': iconCode},
            'amount': t.amount.toStringAsFixed(2),
            if (t.accountId != null) 'account_id': t.accountId,
            if (t.categoryId != null) 'category_id': t.categoryId,
            if (t.toAccountId != null) 'transfer_account_id': t.toAccountId,
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
            _scheduleNotify();
            return;
          }
        }
        throw ApiException('Сервер не вернул ID шаблона', 'MISSING_TEMPLATE_ID');
      } on ApiException catch (e) {
        if (_isNetworkError(e)) {
          toAdd = t.copyWith(isPending: true);
        } else {
          _error = e.message; notifyListeners();
          return;
        }
      } catch (e) {
        toAdd = t.copyWith(isPending: true);
      }
    } else {
      toAdd = t;
    }
    _templates.add(toAdd);
    await _saveTemplates();
    _scheduleNotify();
  }

  Future<void> deleteTemplate(String id) async {
    _error = null;
    // Hide locally first so it disappears even if the server ignores/errors.
    _deletedTemplateIds.add(id);
    _templates.removeWhere((t) => t.id == id);
    await _saveTemplates();
    _scheduleNotify();
    if (authService.isAuthenticated) {
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
  }

  Future<void> syncPendingAccounts() async {
    if (!authService.isAuthenticated) return;
    final pending = _accounts.where((a) => a.isPending).toList();
    if (pending.isEmpty) return;
    for (final a in pending) {
      try {
        final now = formatApiDateTime();
        final resp = await authService.apiService.addAccount({
          'accounts': [{
            'name': a.name,
            'init_balance': (a.initBalance > 0 ? a.initBalance : a.balance).toStringAsFixed(2),
            'type_id': _accountTypeToApi(a.type),
            'state': a.isArchived ? '2' : (a.isFavorite ? '1' : '0'),
            if (a.currencyId != null) 'currency_id': a.currencyId else 'currency_id': '1',
            'icon': _accountIconToApi(a.icon),
            'include_in_total': a.includeInTotal ? '1' : '0',
            'created_at': now,
            'updated_at': now,
            ..._creditFields(a),
          }]
        });
        final accounts = resp['accounts'] as List<dynamic>?;
        final serverId = accounts?.isNotEmpty == true ? (accounts!.first as Map<String, dynamic>)['id']?.toString() : null;
        final idx = _accounts.indexWhere((x) => x.id == a.id);
        if (idx >= 0) {
          _accounts[idx] = _accounts[idx].copyWith(id: (serverId != null && serverId.isNotEmpty) ? serverId : a.id, isPending: false);
        }
      } catch (e) {
        debugPrint('Sync pending account ${a.id} failed: $e');
      }
    }
    _scheduleNotify();
  }

  Future<void> syncPendingCategories() async {
    if (!authService.isAuthenticated) return;
    final pending = _categories.where((c) => c.isPending).toList();
    if (pending.isEmpty) return;
    for (final c in pending) {
      try {
        final now = formatApiDateTime();
        final typeCode = c.type == 'expense' ? '-1' : '1';
        final data = await apiClient.postCategoryV2({
          'name': c.name, 'type': typeCode, 'icon': _categoryIconToApi(c.icon),
          'system_id': _systemIdForLogical(c.icon), 'custom': c.isDefault ? '0' : '1',
          'parent_id': c.parentId ?? '0', 'is_hidden': '0', 'created_at': now, 'updated_at': now,
        });
        final categories = data['categories'] as List<dynamic>?;
        final serverId = categories?.isNotEmpty == true ? (categories!.first as Map<String, dynamic>)['id']?.toString() : null;
        final idx = _categories.indexWhere((x) => x.id == c.id);
        if (idx >= 0) {
          _categories[idx] = _categories[idx].copyWith(id: (serverId != null && serverId.isNotEmpty) ? serverId : c.id, isPending: false);
        }
      } catch (e) {
        debugPrint('Sync pending category ${c.id} failed: $e');
      }
    }
    _scheduleNotify();
  }

  Future<void> syncPendingTemplates() async {
    if (!authService.isAuthenticated) return;
    final pending = _templates.where((t) => t.isPending).toList();
    if (pending.isEmpty) return;
    for (final t in pending) {
      try {
        final now = formatApiDateTime();
        final typeCode = t.type == 'expense' ? 0 : t.type == 'income' ? 1 : 2;
        final clientId = DateTime.now().millisecondsSinceEpoch.toString();
        final userId = authService.userId ?? '';
        final catIcon = t.categoryId != null ? categories.where((c) => c.id == t.categoryId).firstOrNull?.icon : null;
        final iconCode = catIcon ?? 'catimg1';
        final resp = await authService.apiService.addTemplate({
          'operationPatterns': [{
            'client_id': clientId, 'user_id': userId, 'name': t.name, 'type': typeCode,
            'icon': {'code': iconCode},
            'amount': t.amount.toStringAsFixed(2),
            if (t.accountId != null) 'account_id': t.accountId,
            if (t.categoryId != null) 'category_id': t.categoryId,
            if (t.toAccountId != null) 'transfer_account_id': t.toAccountId,
            if (t.comment != null) 'comment': t.comment,
            if (t.tags != null) 'tags': t.tags,
            'created_at': now, 'updated_at': now,
          }]
        }, options: 'client');
        final patterns = resp['operationPatterns'] as List<dynamic>?;
        final serverId = patterns?.isNotEmpty == true ? (patterns!.first as Map<String, dynamic>)['id']?.toString() : null;
        final idx = _templates.indexWhere((x) => x.id == t.id);
        if (idx >= 0) {
          _templates[idx] = _templates[idx].copyWith(id: (serverId != null && serverId.isNotEmpty) ? serverId : t.id, isPending: false);
        }
      } catch (e) {
        debugPrint('Sync pending template ${t.id} failed: $e');
      }
    }
    await _saveTemplates();
    _scheduleNotify();
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _templates.map((t) => t.toJson()).toList();
    await prefs.setString('easyfinance_templates', jsonEncode(data));
    await prefs.setString('easyfinance_deleted_templates', jsonEncode(_deletedTemplateIds.toList()));
  }

  Future<void> _loadTemplates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('easyfinance_templates');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _templates = list.map((e) => OperationTemplate.fromLocalJson(e as Map<String, dynamic>)).toList();
      }
      final delRaw = prefs.getString('easyfinance_deleted_templates');
      if (delRaw != null) {
        final list = jsonDecode(delRaw) as List<dynamic>;
        _deletedTemplateIds.addAll(list.map((e) => e.toString()));
      }
      _scheduleNotify();
    } catch (_) {
      _templates = [];
    }
  }

  // --- Tags ---

  Future<void> _registerTags(String? tagsStr) async {
    if (tagsStr == null || tagsStr.isEmpty) return;
    final names = tagsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (names.isEmpty) return;
    await refreshTags();
    final existing = _tags.map((t) => t.name.toLowerCase()).toSet();
    for (final name in names) {
      if (existing.contains(name.toLowerCase())) continue;
      if (_deletedTagNames.contains(name.toLowerCase())) continue;
      existing.add(name.toLowerCase());
      await addTag(Tag(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), name: name));
    }
  }

  Future<void> addTag(Tag tag) async {
    _deletedTagNames.remove(tag.name.toLowerCase());
    if (_tags.any((t) => t.name.toLowerCase() == tag.name.toLowerCase())) return;
    if (authService.isAuthenticated) {
      try {
        final resp = await authService.apiService.addTag({
          'tags': [
            {
              'name': tag.name,
            }
          ],
        });
        final dynamic respData = resp;
        List<dynamic>? tags;
        if (respData is List) {
          tags = respData; 
        } else if (respData is Map) {
          tags = (respData['tags'] ?? respData['data']) as List<dynamic>?;
        }
        debugPrint('[TAGS][store.addTag] tagsLen=${tags?.length}');
        if (tags != null && tags.isNotEmpty) {
          final serverId = tags[0]['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            _tags.add(Tag(id: serverId, name: tag.name));
            await _saveCache();
            _scheduleNotify();
            return;
          }
        }
      } catch (e) {
        debugPrint('addTag error: $e');
      }
    }
    // Local fallback
    _tags.add(tag);
    await _saveCache();
    _scheduleNotify();
  }

  List<Operation> operationsUsingTag(String name) {
    final key = name.toLowerCase();
    return _operations.where((op) => !op.isDeleted && getTagsForOperation(op).any((n) => n.toLowerCase() == key)).toList();
  }

  Future<void> deleteTag(Tag tag, {String? replacementTagName}) async {
    final name = tag.name;
    final key = name.toLowerCase();
    if (name.isEmpty) return;

    String? repl = replacementTagName?.trim();
    if (repl != null && (repl.isEmpty || repl.toLowerCase() == key)) repl = null;
    final useRepl = repl != null;

    // Reassign (or strip) the tag on every operation that references it.
    for (final op in List<Operation>.from(_operations)) {
      if (op.isDeleted) continue;
      final names = getTagsForOperation(op);
      if (!names.any((n) => n.toLowerCase() == key)) continue;
      final kept = names.where((n) => n.toLowerCase() != key).toList();
      if (useRepl) {
        final r = repl;
        if (!kept.any((n) => n.toLowerCase() == r.toLowerCase())) kept.add(r);
      }
      final newStr = _rebuildTagsString(op.tags, kept);
      if (newStr == (op.tags ?? '')) continue;
      try {
        await updateOperation(op.copyWith(tags: newStr));
      } catch (e) {
        debugPrint('deleteTag reassign op error: $e');
      }
    }

    // Hide everywhere by name (server tags.get may still return it).
    _deletedTagNames.add(key);

    // Soft-delete on the server catalog (best-effort; ignored if no real id).
    if (authService.isAuthenticated && tag.id.isNotEmpty) {
      try {
        final now = formatApiDateTime();
        await authService.apiService.setTag({'id': tag.id, 'name': name, 'deleted_at': now}, tagId: tag.id);
      } catch (e) {
        debugPrint('deleteTag server error: $e');
      }
    }

    _tags.removeWhere((t) => t.id == tag.id || t.name.toLowerCase() == key);
    await _saveCache();
    _scheduleNotify();
  }

  String _rebuildTagsString(String? original, List<String> kept) {
    final s = (original ?? '').trim();
    if (s.startsWith('[')) return jsonEncode(kept);
    return kept.join(',');
  }

  Future<void> refreshTags() async {
    try {
      final server = await authService.apiService.getTags();
      final localOnly = _tags.where((t) => t.id.isEmpty).toList();
      final merged = <Tag>[...server.where((t) => !_deletedTagNames.contains(t.name.toLowerCase()))];
      for (final l in localOnly) {
        if (_deletedTagNames.contains(l.name.toLowerCase())) continue;
        if (!merged.any((t) => t.name.toLowerCase() == l.name.toLowerCase())) merged.add(l);
      }
      _tags = merged;
      await _saveCache();
      _scheduleNotify();
    } catch (e) {
      debugPrint('refreshTags error: $e');
    }
  }

  Future<void> _syncPendingTags() async {
    if (!authService.isAuthenticated) return;
    final pending = _tags.where((t) => t.id.isEmpty).toList();
    for (final t in pending) {
      try {
        final resp = await authService.apiService.addTag({
          'tags': [
            {
              'name': t.name,
            }
          ],
        });
        final dynamic respData = resp;
        List<dynamic>? tags;
        if (respData is List) {
          tags = respData;
        } else if (respData is Map) {
          tags = (respData['tags'] ?? respData['data']) as List<dynamic>?;
        }
        if (tags != null && tags.isNotEmpty) {
          final serverId = tags[0]['id']?.toString();
          if (serverId != null && serverId.isNotEmpty) {
            final idx = _tags.indexWhere((x) => x.id.isEmpty && x.name.toLowerCase() == t.name.toLowerCase());
            if (idx >= 0) _tags[idx] = Tag(id: serverId, name: t.name);
          }
        }
      } catch (e) {
        debugPrint('syncPendingTag error: $e');
      }
    }
    await _saveCache();
    _scheduleNotify();
  }

  List<String> getTagsForOperation(Operation op) {
    final cached = _tagsCache[op.id];
    if (cached != null) return cached;
    final raw = op.tags;
    if (raw == null || raw.isEmpty) { _tagsCache[op.id] = const []; return const []; }
    final s = raw.trim();
    List<String> result;
    if (s.startsWith('[')) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is List) {
          result = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          _tagsCache[op.id] = result;
          return result;
        }
      } catch (_) {}
    }
    result = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    _tagsCache[op.id] = result;
    return result;
  }

  /// All tags: server catalog (tags.get) merged with tag names used directly on operations.
  List<Tag> get allTags {
    final byName = <String, Tag>{};
    for (final t in _tags) {
      if (_deletedTagNames.contains(t.name.toLowerCase())) continue;
      byName[t.name.toLowerCase()] = t;
    }
    for (final op in _operations) {
      if (op.isDeleted) continue;
      for (final name in getTagsForOperation(op)) {
        final key = name.toLowerCase();
        if (_deletedTagNames.contains(key)) continue;
        byName.putIfAbsent(key, () => Tag(id: '', name: name));
      }
    }
    final list = byName.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }
}
