import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../models/account.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';
import '../../utils/currency_utils.dart';
import '../../utils/format.dart';

class MasterOnboardingScreen extends StatefulWidget {
  final List<int> masterChain;

  const MasterOnboardingScreen({super.key, required this.masterChain});

  @override
  State<MasterOnboardingScreen> createState() => _MasterOnboardingScreenState();
}

class _MasterOnboardingScreenState extends State<MasterOnboardingScreen> {
  late List<int> _baseSteps;
  late List<int> _steps;
  int _currentStepIndex = 0;
  bool _loading = false;
  String? _error;

  final _pageController = PageController();

  final _budgetTotalController = TextEditingController();
  final _utilitiesAmountController = TextEditingController();
  final _rentingAmountController = TextEditingController();

  String _accountType = 'man';
  String _selectedCurrencyId = '1';
  final Set<String> _watchedCurrencyIds = {'2', '3'};
  Account? _walletAccount;
  bool _walletOwnsAccount = false;
  bool _hasAutomobile = false;
  bool _hasMotocycle = false;
  bool _hasChildren = false;
  bool _hasAnimals = false;
  int _housingOption = 3;

  bool get _paysUtilities => _housingOption == 1 || _housingOption == 3;
  bool get _paysRenting => _housingOption == 2 || _housingOption == 3;

  @override
  void initState() {
    super.initState();
    _baseSteps = _computeSteps();
    _steps = _applyAccountType(_baseSteps);
    final store = context.read<FinanceStore>();
    final userCurrency = store.currentUser?.currency ?? 'RUB';
    _selectedCurrencyId = currencyCodeToId[userCurrency] ?? '1';
    _watchedCurrencyIds.remove(_selectedCurrencyId);
    _budgetTotalController.addListener(_onIncomeChanged);
  }

  List<int> _computeSteps() {
    final filtered = widget.masterChain.where((s) => const {1, 2, 3, 5, 8}.contains(s)).toList();
    if (filtered.isEmpty) return [1, 8, 2, 3, 5];
    return filtered;
  }

  List<int> _applyAccountType(List<int> base) {
    if (_accountType == 'company') {
      return base.where((s) => s != 2 && s != 3).toList();
    }
    return base;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _budgetTotalController.removeListener(_onIncomeChanged);
    _budgetTotalController.dispose();
    _utilitiesAmountController.dispose();
    _rentingAmountController.dispose();
    super.dispose();
  }

  void _onIncomeChanged() => setState(() {});

  bool get _isLastStep => _currentStepIndex == _steps.length - 1;
  bool get _isFirstStep => _currentStepIndex == 0;

  String get _mainCurrencyCode => currencyIdToCode[_selectedCurrencyId] ?? 'RUB';

  double _parseAmount(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  double get _incomeValue => _parseAmount(_budgetTotalController.text);
  double get _utilitiesValue => _parseAmount(_utilitiesAmountController.text);
  double get _rentingValue => _parseAmount(_rentingAmountController.text);
  double get _targetValue => _incomeValue * 6;

  /// Ensures a cash wallet account exists in the selected main currency.
  /// Called after the currency step and again before [finishMaster] so the
  /// server can bind the master goal to the account.
  Future<bool> _ensureWalletAccount() async {
    if (!mounted) return false;
    final store = context.read<FinanceStore>();

    if (_walletAccount != null) {
      if (_walletOwnsAccount && _walletAccount!.currencyId != _selectedCurrencyId) {
        final updated = _walletAccount!.copyWith(
          currency: _mainCurrencyCode,
          currencyId: _selectedCurrencyId,
        );
        await store.updateAccount(updated);
        if (store.error != null) return false;
        _walletAccount = updated;
      }
      return true;
    }

    var list = store.accounts;
    if (list.isEmpty) {
      try {
        list = await store.authService.apiService.getAccounts();
      } catch (_) {}
    }
    if (list.isNotEmpty) {
      _walletAccount = list.first;
      return true;
    }

    if (!mounted) return false;
    final now = formatApiDateTime();
    final acc = Account(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: context.tr('onboarding.wallet_name'),
      balance: 0,
      type: 'cash',
      currencyId: _selectedCurrencyId,
      currency: _mainCurrencyCode,
      icon: 'cash',
      color: '#16A34A',
      initBalance: 0,
      createdAt: now,
      updatedAt: now,
      description: context.tr('onboarding.wallet_description'),
    );
    await store.addAccount(acc);
    if (store.error != null) return false;
    _walletOwnsAccount = true;
    _walletAccount = store.accounts.where((a) => a.id == acc.id).firstOrNull ??
        store.accounts.where((a) => a.name == acc.name).firstOrNull ??
        acc;
    return true;
  }

  Future<void> _next() async {
    if (_isLastStep) {
      await _finish();
      return;
    }

    final stepId = _steps[_currentStepIndex];

    if (stepId == 8) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final apiClient = context.read<FinanceStore>().authService.apiClient;
        await apiClient.setMaster({'account_type': _accountType});
        if (!mounted) return;
        setState(() {
          _loading = false;
          final newSteps = _applyAccountType(_baseSteps);
          final currentStepId = _steps[_currentStepIndex];
          _steps = newSteps;
          _currentStepIndex = newSteps.indexOf(currentStepId) + 1;
        });
        _pageController.jumpToPage(_currentStepIndex);
      } on ApiException catch (e) {
        if (mounted) {
          setState(() {
            _error = e.message;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = context.tr('onboarding.finish_error');
            _loading = false;
          });
        }
      }
      return;
    }

    if (stepId == 1) {
      setState(() {
        _loading = true;
        _error = null;
      });
      final ok = await _ensureWalletAccount();
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = context.read<FinanceStore>().error ?? context.tr('onboarding.finish_error');
          _loading = false;
        });
        return;
      }
      setState(() => _loading = false);
    }

    setState(() => _currentStepIndex++);
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _back() {
    if (_isFirstStep) return;
    setState(() => _currentStepIndex--);
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    if (_steps.contains(3)) {
      final leftover = _incomeValue - _utilitiesValue - _rentingValue;
      if (_incomeValue <= 0 || leftover <= 0) {
        setState(() => _error = context.tr('onboarding.budget_error'));
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final store = context.read<FinanceStore>();
      final apiClient = store.authService.apiClient;

      final ensured = await _ensureWalletAccount();
      if (!mounted) return;
      if (!ensured) {
        setState(() {
          _error = store.error ?? context.tr('onboarding.finish_error');
          _loading = false;
        });
        return;
      }
      await store.syncPendingAccounts();

      await apiClient.setMaster({
        'account_type': _accountType,
        'currency_default': int.parse(_selectedCurrencyId),
        'currency_list': _watchedCurrencyIds.map(int.parse).toList(),
        'has_automobile': _hasAutomobile,
        'has_motocycle': _hasMotocycle,
        'has_children': _hasChildren,
        'has_animals': _hasAnimals,
        'pays_utilities': _paysUtilities,
        'pays_renting': _paysRenting,
      });

      await apiClient.finishMaster({
        'budgetTotalAmount': _incomeValue,
        'utilitiesAmount': _paysUtilities ? _utilitiesValue : 0,
        'rentingAmount': _paysRenting ? _rentingValue : 0,
        'targetAmount': _steps.contains(3) ? _targetValue : 0,
      });

      if (!mounted) return;
      _goToMain();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = context.tr('onboarding.finish_error');
          _loading = false;
        });
      }
    }
  }

  void _goToMain() {
    final store = context.read<FinanceStore>();
    final plannedStore = context.read<PlannedPaymentStore>();
    Navigator.of(context).pushNamedAndRemoveUntil('/main', (r) => false);
    store.fetchAllData();
    plannedStore.syncFromServer();
    NotificationService().rescheduleAll();
    NotificationService().trackAppOpen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('onboarding.title')),
        centerTitle: true,
        leading: _isFirstStep
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: _steps.map((stepId) => _buildStep(stepId)).toList(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(_steps.length, (i) {
          final isCurrent = i == _currentStepIndex;
          final isDone = i < _currentStepIndex;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent ? AppColors.primary : (isDone ? AppColors.primary : AppColors.textSecondary),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: isCurrent ? Colors.white : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (i < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: i < _currentStepIndex ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.expense, fontSize: 14)),
            const SizedBox(height: 12),
          ],
          AppButton(
            title: _isLastStep ? context.tr('onboarding.finish') : context.tr('onboarding.next'),
            onPressed: _loading ? null : _next,
            loading: _loading,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int stepId) {
    switch (stepId) {
      case 1:
        return _buildCurrencyStep();
      case 8:
        return _buildAccountTypeStep();
      case 2:
        return _buildCategoriesStep();
      case 3:
        return _buildBudgetStep();
      case 5:
        return _buildHowToStartStep();
      default:
        return const Center(child: Text('Unknown step'));
    }
  }

  Widget _buildAccountTypeStep() {
    final types = [
      {'value': 'man', 'icon': Icons.male, 'label': context.tr('onboarding.account_man')},
      {'value': 'woman', 'icon': Icons.female, 'label': context.tr('onboarding.account_woman')},
      {'value': 'family', 'icon': Icons.family_restroom, 'label': context.tr('onboarding.account_family')},
      {'value': 'company', 'icon': Icons.business, 'label': context.tr('onboarding.account_company')},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            context.tr('onboarding.step8_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('onboarding.step8_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          ...types.map((t) {
            final isSelected = _accountType == t['value'];
            return InkWell(
              onTap: () => setState(() => _accountType = t['value'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(t['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 28),
                    const SizedBox(width: 16),
                    Text(t['label'] as String, style: TextStyle(fontSize: 16, color: AppColors.textFor(context), fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                    const Spacer(),
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCurrencyStep() {
    final currencyItems = allCurrencyCodes.map((code) {
      final id = currencyCodeToId[code];
      final symbol = currencySymbol(code);
      return {'id': id, 'code': code, 'symbol': symbol};
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            context.tr('onboarding.step1_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('onboarding.step1_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ...currencyItems.map((item) {
            final id = item['id'] as String;
            final code = item['code'] as String;
            final symbol = item['symbol'] as String;
            final isSelected = id == _selectedCurrencyId;
            return InkWell(
              onTap: () => setState(() {
                _selectedCurrencyId = id;
                _watchedCurrencyIds.remove(id);
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    Text(code, style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text(
            context.tr('onboarding.step1_watch_title'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...currencyItems.map((item) {
            final id = item['id'] as String;
            final code = item['code'] as String;
            final symbol = item['symbol'] as String;
            if (id == _selectedCurrencyId) return const SizedBox.shrink();
            final isChecked = _watchedCurrencyIds.contains(id);
            return InkWell(
              onTap: () => setState(() {
                if (isChecked) {
                  _watchedCurrencyIds.remove(id);
                } else {
                  _watchedCurrencyIds.add(id);
                }
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isChecked ? AppColors.primary : AppColors.border),
                  color: isChecked ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(
                      isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                      color: isChecked ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(symbol, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    Text(code, style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCategoriesStep() {
    final housingOptions = [
      {'value': 1, 'label': context.tr('onboarding.housing_1')},
      {'value': 2, 'label': context.tr('onboarding.housing_2')},
      {'value': 3, 'label': context.tr('onboarding.housing_3')},
      {'value': 4, 'label': context.tr('onboarding.housing_4')},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            context.tr('onboarding.step2_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('onboarding.step2_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildToggle(context.tr('onboarding.has_automobile'), _hasAutomobile, Icons.directions_car, (v) => setState(() => _hasAutomobile = v)),
          _buildToggle(context.tr('onboarding.has_motocycle'), _hasMotocycle, Icons.two_wheeler, (v) => setState(() => _hasMotocycle = v)),
          _buildToggle(context.tr('onboarding.has_children'), _hasChildren, Icons.child_care, (v) => setState(() => _hasChildren = v)),
          _buildToggle(context.tr('onboarding.has_animals'), _hasAnimals, Icons.pets, (v) => setState(() => _hasAnimals = v)),
          const SizedBox(height: 24),
          Text(
            context.tr('onboarding.housing_title'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...housingOptions.map((o) {
            final opt = o['value'] as int;
            final isSelected = _housingOption == opt;
            return InkWell(
              onTap: () => setState(() => _housingOption = opt),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('$opt. ${o['label'] as String}', style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildBudgetStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            context.tr('onboarding.step3_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('onboarding.step3_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          AppInput(
            label: context.tr('onboarding.budget_total'),
            controller: _budgetTotalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          if (_paysUtilities) ...[
            AppInput(
              label: context.tr('onboarding.utilities_amount'),
              controller: _utilitiesAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
          ],
          if (_paysRenting) ...[
            AppInput(
              label: context.tr('onboarding.renting_amount'),
              controller: _rentingAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primary.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('onboarding.target_banner', args: [_incomeValue > 0 ? formatMoneyWhole(_targetValue, currency: _mainCurrencyCode) : '']),
                  style: TextStyle(fontSize: 16, color: AppColors.textFor(context), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('onboarding.target_hint'),
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHowToStartStep() {
    final tips = [
      context.tr('onboarding.tip1'),
      context.tr('onboarding.tip2'),
    ];

    final helps = [
      {'title': context.tr('onboarding.help1_title'), 'text': context.tr('onboarding.help1_text')},
      {'title': context.tr('onboarding.help2_title'), 'text': context.tr('onboarding.help2_text')},
      {'title': context.tr('onboarding.help3_title'), 'text': context.tr('onboarding.help3_text')},
      {'title': context.tr('onboarding.help4_title'), 'text': context.tr('onboarding.help4_text')},
      {'title': context.tr('onboarding.help5_title'), 'text': context.tr('onboarding.help5_text')},
      {'title': context.tr('onboarding.help6_title'), 'text': context.tr('onboarding.help6_text')},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            context.tr('onboarding.step5_title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('onboarding.step5_subtitle'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...tips.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                      child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(entry.value, style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          ...helps.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.border, width: 1),
                  ),
                  color: AppColors.cardFor(context),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      title: Text(
                        h['title'] as String,
                        style: TextStyle(fontSize: 16, color: AppColors.textFor(context), fontWeight: FontWeight.w500),
                      ),
                      iconColor: AppColors.primary,
                      collapsedIconColor: AppColors.textSecondary,
                      children: [
                        Text(
                          h['text'] as String,
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, IconData icon, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: value ? AppColors.primary : AppColors.textSecondary, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: AppColors.textFor(context)))),
              Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}