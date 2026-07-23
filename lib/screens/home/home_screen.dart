import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/progress_bar.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/home/fin_health_card.dart';
import '../../components/home/quick_actions.dart';
import '../../store/finance_store.dart';
import '../../models/financial_event.dart';
import '../../theme/theme.dart';
import '../../utils/calc.dart';
import '../../utils/format.dart';
import '../../utils/currency_utils.dart';
import '../../store/planned_payment_store.dart';
import '../accounts/add_account_screen.dart';
import '../accounts/accounts_screen.dart';
import '../budget/plan_screen.dart';
import '../recommendations/recommendations_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<FinanceStore, PlannedPaymentStore>(
      builder: (context, store, plannedPayments, _) {
        final indicators = calcFinHealth(store.accounts, store.operations, store.budgets);
        final accountType = store.currentUser?.accountType ?? 'individual';

        return ScreenScaffold(
          title: 'EasyFinance',
          isLoading: store.isLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHint(hintId: 'home', text: 'Здесь вы видите общий баланс, бюджет на месяц и ближайшие платежи. Добавляйте доходы и расходы через кнопки быстрых действий.'),
              _buildBalanceBanner(context, store),
              const SizedBox(height: 16),
              QuickActions(
                onAddIncome: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'income'}),
                onAddExpense: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'expense'}),
                onAddTransfer: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'transfer'}),
                onScan: () => Navigator.pushNamed(context, '/scan-receipt'),
              ),
              const SizedBox(height: 16),
              if (accountType == 'entrepreneur') ...[
                _buildAccountsSection(context, store),
                const SizedBox(height: 16),
              ],
              FinHealthCard(indicators: indicators),
              const SizedBox(height: 16),
              _buildRatesSection(context, store),
              _buildRecommendationsSection(context, store),
              _buildBudgetsSection(context, store),
              _buildGoalsSection(context, store),
              _buildUpcomingPaymentsSection(context, plannedPayments, store),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceBanner(BuildContext context, FinanceStore store) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('home.total_balance'), style: TextStyle(color: Colors.white70, fontSize: 13)),
                Icon(Icons.chevron_right, color: Colors.white54, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(store.fmt(store.totalBalance), style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip('+${store.fmt(store.monthIncome)}', AppColors.success),
                const SizedBox(width: 12),
                _chip('-${store.fmt(store.monthExpense)}', AppColors.expense),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsSection(BuildContext context, FinanceStore store) {
    final accounts = store.accounts.where((a) => !a.isArchived).toList();
    if (accounts.isEmpty) return const SizedBox.shrink();

    final iconMap = {'cash': Icons.money, 'credit_card': Icons.credit_card, 'savings': Icons.savings, 'account_balance': Icons.account_balance, 'wallet': Icons.wallet, 'payments': Icons.payments};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('accounts.title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
        const SizedBox(height: 8),
        ...accounts.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddAccountScreen(accountId: a.id))),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: _parseColor(a.color).withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(iconMap[a.icon] ?? Icons.account_balance, color: _parseColor(a.color)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                        const SizedBox(height: 2),
                        _typeBadge(context, a.type),
                      ],
                    ),
                  ),
                  Text(store.fmt(a.balance, fromCurrency: a.currency), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: a.balance >= 0 ? AppColors.textFor(context) : AppColors.expense)),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _typeBadge(BuildContext context, String type) {
    final labels = {'account': context.tr('account.account_type'), 'card': context.tr('account.card_type'), 'credit': context.tr('account.credit_type'), 'savings': context.tr('account.savings_type'), 'electronic': context.tr('account.electronic_type')};
    final label = labels[type] ?? type;
    return Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary));
  }

  Widget _buildRatesSection(BuildContext context, FinanceStore store) {
    final codes = store.watchedCurrencies.where((c) => c != 'RUB' && store.rates.containsKey(c)).toList();
    if (codes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr('home.currency_rates'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showCurrencyPicker(context, store),
                  child: Icon(Icons.tune, size: 20, color: AppColors.textSecondaryFor(context)),
                ),
                const SizedBox(width: 12),
                _currencyDropdown(context, store),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (int r = 0; r < (codes.length / 3).ceil(); r++)
                Padding(
                  padding: EdgeInsets.only(top: r > 0 ? 12 : 0),
                  child: Row(
                    children: [
                      for (int c = 0; c < 3 && r * 3 + c < codes.length; c++)
                        Expanded(
                          child: Row(
                            children: [
                              Text(currencySymbol(codes[r * 3 + c]), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                              const SizedBox(width: 4),
                              Text(codes[r * 3 + c], style: TextStyle(fontSize: 11, color: AppColors.textSecondaryFor(context))),
                              const Spacer(),
                              Text(store.rates[codes[r * 3 + c]]!.toStringAsFixed(1), style: TextStyle(fontSize: 14, color: AppColors.textFor(context))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _currencyDropdown(BuildContext context, FinanceStore store) {
    final codes = store.watchedCurrencies.where((c) => store.rates.containsKey(c)).toList();
    if (codes.length < 2) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _showCurrencySwitcher(context, store, codes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryLightFor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(store.displayCurrencySymbol, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  void _showCurrencySwitcher(BuildContext context, FinanceStore store, List<String> codes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('home.display_currency'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
        content: RadioGroup<String>(
          groupValue: store.displayCurrency,
          onChanged: (v) {
            if (v != null) {
              store.setDisplayCurrency(v);
              Navigator.pop(ctx);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: codes.map((code) => RadioListTile<String>(
              title: Row(
                children: [
                  Text(currencySymbol(code), style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(code, style: TextStyle(fontSize: 15)),
                ],
              ),
              value: code,
              activeColor: AppColors.primary,
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, FinanceStore store) {
    final allCodes = allCurrencyCodes.where((c) => c != 'RUB').toList();
    final selected = List<String>.from(store.watchedCurrencies.where((c) => c != 'RUB'));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: Text(context.tr('home.select_currencies'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...allCodes.map((code) => CheckboxListTile(
                  value: selected.contains(code),
                  title: Row(
                    children: [
                      Text(currencySymbol(code), style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(code, style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      Text(_currencyName(context, code), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                    ],
                  ),
                  onChanged: (v) {
                    setInnerState(() {
                      if (v == true) {
                        selected.add(code);
                      } else {
                        selected.remove(code);
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.trailing,
                )),
              ],
            ),
          ),
          actions: [
              TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('home.cancel')),
            ),
            TextButton(
              onPressed: () {
                final finalList = ['RUB', ...selected];
                store.setWatchedCurrencies(finalList);
                Navigator.pop(ctx);
              },
              child: Text(context.tr('home.save'), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  String _currencyName(BuildContext context, String code) {
    const keys = {'USD': 'currency.usd_name', 'EUR': 'currency.eur_name', 'GBP': 'currency.gbp_name', 'CHF': 'currency.chf_name', 'CNY': 'currency.cny_name', 'JPY': 'currency.jpy_name', 'BYN': 'currency.byn_name', 'UAH': 'currency.uah_name', 'KZT': 'currency.kzt_name', 'PLN': 'currency.pln_name', 'CZK': 'currency.czk_name', 'SEK': 'currency.sek_name', 'NOK': 'currency.nok_name'};
    final key = keys[code];
    return key != null ? context.tr(key) : code;
  }

  Widget _buildRecommendationsSection(BuildContext context, FinanceStore store) {
    if (store.recommendations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendationsScreen())),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('home.recommendations'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...store.recommendations.take(3).map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: AppCard(
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(context.tr(r.titleKey, namedArgs: r.titleArgs), style: TextStyle(fontSize: 13, color: AppColors.textFor(context)))),
              ],
            ),
          ),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBudgetsSection(BuildContext context, FinanceStore store) {
    if (store.budgets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen())),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('home.month_budget'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...store.budgets.where((b) => !b.isDeleted).take(3).map((b) {
          final cat = store.getCategory(b.categoryId);
          final percent = b.limit > 0 ? (b.spent / b.limit * 100) : 0.0;
          final color = cat?.color != null ? _parseColor(cat!.color) : AppColors.primary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(b.name ?? cat?.name ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                      Text('${store.fmt(b.spent)} / ${store.fmt(b.limit)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressBar(percent: percent, color: color),
                  Text('${percent.round()}%', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryFor(context))),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGoalsSection(BuildContext context, FinanceStore store) {
    if (store.goals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen())),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('home.goals'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...store.goals.where((g) => !g.isCompleted).take(3).map((g) {
          final percent = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(g.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                      ),
                      Text('${percent.round()}%', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressBar(percent: percent, color: _parseColor(g.color)),
                  Text('${store.fmt(g.currentAmount)} / ${store.fmt(g.targetAmount)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryFor(context))),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildUpcomingPaymentsSection(BuildContext context, PlannedPaymentStore plannedPayments, FinanceStore store) {
    if (plannedPayments.upcomingExpenses.isEmpty && plannedPayments.upcomingIncomes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/planned-payments'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('home.upcoming_payments'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...plannedPayments.upcomingEvents.take(5).map((e) => _upcomingTile(context, e, store)),
        _manageButton(context),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _upcomingTile(BuildContext context, FinancialEvent e, FinanceStore store) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: AppCard(
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (e.type == 'income' ? AppColors.success : AppColors.expense).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(e.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward, size: 20, color: e.type == 'income' ? AppColors.success : AppColors.expense),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                Text(formatDate(e.date), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
              ],
            ),
          ),
          Text(store.fmt(e.amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: e.type == 'income' ? AppColors.success : AppColors.expense)),
        ],
      ),
    ),
  );

  Widget _manageButton(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: TextButton(
      onPressed: () => Navigator.pushNamed(context, '/planned-payments'),
      child: Text(context.tr('home.manage_planned'), style: TextStyle(fontSize: 13, color: AppColors.primary)),
    ),
  );

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
