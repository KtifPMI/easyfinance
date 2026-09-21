import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';
import '../../utils/currency_utils.dart';

class MasterOnboardingScreen extends StatefulWidget {
  final List<int> masterChain;

  const MasterOnboardingScreen({super.key, required this.masterChain});

  @override
  State<MasterOnboardingScreen> createState() => _MasterOnboardingScreenState();
}

class _MasterOnboardingScreenState extends State<MasterOnboardingScreen> {
  late final List<int> _steps;
  int _currentStepIndex = 0;
  bool _loading = false;
  String? _error;

  final _pageController = PageController();

  final _targetAmountController = TextEditingController();
  final _budgetTotalController = TextEditingController();
  final _utilitiesAmountController = TextEditingController();
  final _rentingAmountController = TextEditingController();

  String _accountType = 'man';
  String _selectedCurrencyId = '1';
  bool _hasAutomobile = false;
  bool _hasMotocycle = false;
  bool _hasChildren = false;
  bool _hasAnimals = false;
  bool _paysUtilities = false;
  bool _paysRenting = false;

  @override
  void initState() {
    super.initState();
    _steps = _computeSteps();
    final store = context.read<FinanceStore>();
    final userCurrency = store.currentUser?.currency ?? 'RUB';
    _selectedCurrencyId = currencyCodeToId[userCurrency] ?? '1';
  }

  List<int> _computeSteps() {
    final filtered = widget.masterChain.where((s) => const {1, 2, 3, 5, 8}.contains(s)).toList();
    if (filtered.isEmpty) return [8, 1, 2, 3, 5];
    return filtered;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _targetAmountController.dispose();
    _budgetTotalController.dispose();
    _utilitiesAmountController.dispose();
    _rentingAmountController.dispose();
    super.dispose();
  }

  bool get _isLastStep => _currentStepIndex == _steps.length - 1;
  bool get _isFirstStep => _currentStepIndex == 0;

  Future<void> _next() async {
    if (_isLastStep) {
      await _finish();
      return;
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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<FinanceStore>().authService.apiClient;

      await apiClient.setMaster({
        'account_type': _accountType,
        'currency_default': int.parse(_selectedCurrencyId),
        'has_automobile': _hasAutomobile,
        'has_motocycle': _hasMotocycle,
        'has_children': _hasChildren,
        'has_animals': _hasAnimals,
        'pays_utilities': _paysUtilities,
        'pays_renting': _paysRenting,
      });

      final budgetTotal = double.tryParse(_budgetTotalController.text) ?? 0;
      final utilitiesAmount = double.tryParse(_utilitiesAmountController.text) ?? 0;
      final rentingAmount = double.tryParse(_rentingAmountController.text) ?? 0;
      final targetAmount = double.tryParse(_targetAmountController.text) ?? 0;

      await apiClient.finishMaster({
        'budgetTotalAmount': budgetTotal,
        'utilitiesAmount': utilitiesAmount,
        'rentingAmount': rentingAmount,
        'targetAmount': targetAmount,
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
                      color: i < _currentStepIndex ? AppColors.primary : AppColors.textSecondary.withOpacity(0.3),
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
      case 8:
        return _buildAccountTypeStep();
      case 1:
        return _buildCurrencyStep();
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
                  color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
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
          const SizedBox(height: 32),
          ...currencyItems.map((item) {
            final id = item['id'] as String;
            final code = item['code'] as String;
            final symbol = item['symbol'] as String;
            final isSelected = id == _selectedCurrencyId;
            return InkWell(
              onTap: () => setState(() => _selectedCurrencyId = id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                  color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
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
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildCategoriesStep() {
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
          _buildToggle(context.tr('onboarding.pays_utilities'), _paysUtilities, Icons.home_repair_service, (v) => setState(() => _paysUtilities = v)),
          _buildToggle(context.tr('onboarding.pays_renting'), _paysRenting, Icons.home, (v) => setState(() => _paysRenting = v)),
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
              Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
            ],
          ),
        ),
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
          AppInput(
            label: context.tr('onboarding.utilities_amount'),
            controller: _utilitiesAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          AppInput(
            label: context.tr('onboarding.renting_amount'),
            controller: _rentingAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          AppInput(
            label: context.tr('onboarding.target_amount'),
            controller: _targetAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      context.tr('onboarding.tip3'),
      context.tr('onboarding.tip4'),
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
          const SizedBox(height: 32),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tip, style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
