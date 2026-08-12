import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/progress_bar.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/home/fin_health_card.dart';
import '../../components/common/app_logo.dart';
import '../../store/finance_store.dart';
import '../../models/financial_event.dart';
import '../../theme/theme.dart';
import '../../utils/calc.dart';
import '../../utils/format.dart';
import '../../utils/currency_utils.dart';
import '../../utils/translate_category.dart';
import '../../utils/category_icons.dart';
import '../../components/common/simple_pie_chart.dart';
import '../../store/planned_payment_store.dart';
import '../accounts/add_account_screen.dart';
import '../accounts/accounts_screen.dart';
import '../budget/plan_screen.dart';
import '../recommendations/recommendations_screen.dart';
import '../reports/reports_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<FinanceStore, PlannedPaymentStore>(
      builder: (context, store, plannedPayments, _) {
        final indicators = calcFinHealth(store.accounts, store.operations, store.budgets, store.rates);
        final accountType = store.currentUser?.accountType ?? 'individual';

        return ScreenScaffold(
          title: '',
          showLogo: false,
          titleWidget: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: AppLogo(height: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/ai-assistant'),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.cardFor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderFor(context)),
                    ),
                    padding: const EdgeInsets.only(left: 14, right: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(context.tr('ai_assistant.placeholder'), style: TextStyle(fontSize: 15, color: AppColors.textSecondaryFor(context))),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:                           const Icon(Icons.send, size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          isLoading: store.isLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHint(hintId: 'home', text: context.tr('hints.home')),
              _buildBalanceBanner(context, store),
              const SizedBox(height: 16),
              if (accountType == 'entrepreneur') ...[
                _buildProfitLossSection(context, store),
                const SizedBox(height: 16),
                _buildAccountsSection(context, store),
                const SizedBox(height: 16),
              ],
              FinHealthCard(indicators: indicators),
              const SizedBox(height: 16),
              _buildRatesSection(context, store),
              _buildRecommendationsSection(context, store),
              _buildUpcomingPaymentsSection(context, plannedPayments, store),
              _buildBudgetsSection(context, store),
              _buildGoalsSection(context, store),
              _buildReportsSection(context, store),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceBanner(BuildContext context, FinanceStore store) {
    final savings = store.monthIncome - store.monthExpense;
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
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(context.tr('home.money'), style: TextStyle(color: Colors.white70, fontSize: 14)),
              Icon(Icons.chevron_right, color: Colors.white54, size: 20),
            ]),
            const SizedBox(height: 4),
            Text(store.fmt(store.moneyBalance), style: TextStyle(color: Colors.white, fontSize: 33, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              Text(context.tr('home.capital'), style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const Spacer(),
              Text(store.fmt(store.totalBalance), style: const TextStyle(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _statLine(context.tr('home.income'), store.fmt(store.monthIncome), AppColors.success),
              const SizedBox(width: 12),
              _statLine(context.tr('home.expense'), store.fmt(store.monthExpense), AppColors.expense, align: CrossAxisAlignment.end),
            ]),
            const SizedBox(height: 8),
            _statLine(context.tr('home.profit'), store.fmt(savings), Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _statLine(String label, String amount, Color color, {CrossAxisAlignment align = CrossAxisAlignment.start}) {
    return Expanded(
      child: Column(crossAxisAlignment: align, children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
          child: Text(amount, style: TextStyle(color: color == Colors.white ? const Color(0xFF0F2A14) : Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
      ]),
    );
  }


  Widget _buildProfitLossSection(BuildContext context, FinanceStore store) {
    final now = DateTime.now();
    final monthOps = store.operations.where((o) => !o.isDeleted && store.isInMonth(o.date, now)).toList();
    final income = monthOps.where((o) => o.type == 'income').fold<double>(0, (s, o) => s + o.amount);
    final expense = monthOps.where((o) => o.type == 'expense').fold<double>(0, (s, o) => s + o.amount);
    final profit = income - expense;
    return AppCard(
      child: Column(
        children: [
          Text(context.tr('home.profit_loss'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Column(children: [
                Text(context.tr('home.revenue'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                const SizedBox(height: 4),
                Text(store.fmt(income), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.success)),
              ])),
              Container(width: 1, height: 32, color: AppColors.border),
              Expanded(child: Column(children: [
                Text(context.tr('home.costs'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                const SizedBox(height: 4),
                Text(store.fmt(expense), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.expense)),
              ])),
              Container(width: 1, height: 32, color: AppColors.border),
              Expanded(child: Column(children: [
                Text(context.tr('home.net_profit'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                const SizedBox(height: 4),
                Text(store.fmt(profit), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: profit >= 0 ? AppColors.success : AppColors.expense)),
              ])),
            ],
          ),
        ],
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
        Text(context.tr('accounts.title'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
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
                        Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                        const SizedBox(height: 2),
                        _typeBadge(context, a.type),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(store.fmt(a.balance, fromCurrency: a.currency), maxLines: 1, softWrap: false, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: a.balance >= 0 ? AppColors.textFor(context) : AppColors.expense)),
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
    return Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
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
            Text(context.tr('home.currency_rates'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
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
                              Text(currencySymbol(codes[r * 3 + c]), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                              const SizedBox(width: 4),
                              Text(codes[r * 3 + c], style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                              const Spacer(),
                              Text(store.rates[codes[r * 3 + c]]!.toStringAsFixed(1), style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
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
            Text(store.displayCurrencySymbol, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
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
        title: Text(context.tr('home.display_currency'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: codes.map((code) => RadioListTile<String>(
            title: Row(
              children: [
                Text(currencySymbol(code), style: TextStyle(fontSize: 17)),
                const SizedBox(width: 8),
                Text(code, style: TextStyle(fontSize: 16)),
              ],
            ),
            value: code,
            groupValue: store.displayCurrency,
            onChanged: (v) {
              if (v != null) {
                store.setDisplayCurrency(v);
                Navigator.pop(ctx);
              }
            },
            activeColor: AppColors.primary,
          )).toList(),
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
          title: Text(context.tr('home.select_currencies'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...allCodes.map((code) => CheckboxListTile(
                    value: selected.contains(code),
                    title: Row(
                      children: [
                        Text(currencySymbol(code), style: TextStyle(fontSize: 17)),
                        const SizedBox(width: 8),
                        Text(code, style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(_currencyName(context, code), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
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
              Text(context.tr('home.recommendations'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...store.recommendations.take(3).map((r) => GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendationsScreen())),
          child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr(r.titleKey, namedArgs: r.titleArgs), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textFor(context))),
                      const SizedBox(height: 2),
                      Text(context.tr(r.descKey, namedArgs: r.descArgs), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ))),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBudgetsSection(BuildContext context, FinanceStore store) {
    final pendingCount = store.operations.where((op) => op.isPending).length;

    final totalPlanned = store.budgets.fold(0.0, (sum, b) => sum + b.limit);
    final totalSpent = store.budgets.fold(0.0, (sum, b) => sum + b.spent);
    final totalRemaining = totalPlanned - totalSpent;
    final totalForecast = store.budgets.fold(0.0, (sum, b) => sum + getBudgetForecastPercent(b) * b.limit / 100);
    final budgetForecastPct = totalPlanned > 0 ? (totalForecast / totalPlanned * 100).clamp(0.0, 100.0) : 0.0;
    final forecastColor = budgetForecastColor(budgetForecastPct);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen())),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('home.month_budget'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (pendingCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.sync, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr('home.offline_pending', namedArgs: {'count': pendingCount.toString()}), style: TextStyle(fontSize: 13, color: AppColors.warning))),
              ],
            ),
          ),
        if (totalPlanned > 0)
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen())),
            child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('budget.planned'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
                    Text(store.fmt(totalPlanned), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('budget.spent_total'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
                    Text(store.fmt(totalSpent), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: totalSpent > totalPlanned ? AppColors.expense : AppColors.textFor(context))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('budget.remaining'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
                    Text(store.fmt(totalRemaining), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: totalRemaining < 0 ? AppColors.expense : AppColors.success)),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressBar(percent: budgetForecastPct, color: forecastColor),
                const SizedBox(height: 4),
                Text('${context.tr('budget.forecast')} ${budgetForecastPct.round()}%', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
              ],
            ),
          ),
          ),
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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen(scrollToGoals: true))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('home.goals'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...store.goals.where((g) => !g.isCompleted).take(3).map((g) {
          final percent = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen(scrollToGoals: true))),
              child: AppCard(
                child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                      ),
                      const SizedBox(width: 8),
                      Text('${percent.round()}%', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressBar(percent: percent, color: _parseColor(g.color)),
                  Text('${store.fmt(g.currentAmount)} / ${store.fmt(g.targetAmount)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                ],
              ),
            ),
          ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildUpcomingPaymentsSection(BuildContext context, PlannedPaymentStore plannedPayments, FinanceStore store) {
    if (plannedPayments.events.isEmpty) return const SizedBox.shrink();
    final upcoming = plannedPayments.upcomingEvents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/planned-payments'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('home.upcoming_payments'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.tr('calendar.empty'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          )
        else
          ...upcoming.take(5).map((e) => GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/planned-payments'),
          child: _upcomingTile(context, e, store),
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _upcomingTile(BuildContext context, FinancialEvent e, FinanceStore store) {
    final cat = e.categoryId != null ? store.getCategory(e.categoryId) : null;
    final iconData = cat != null ? categoryIconFor(cat, allCategories: store.categories) : (e.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward);
    final iconColor = e.type == 'income' ? AppColors.success : AppColors.expense;
    return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: AppCard(
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                Text(formatDate(e.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(store.fmt(e.amount), maxLines: 1, softWrap: false, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: e.type == 'income' ? AppColors.success : AppColors.expense)),
        ],
      ),
    ),
  );
  }

  Widget _buildReportsSection(BuildContext context, FinanceStore store) {
    final now = DateTime.now();
    final monthOps = store.operations.where((o) => !o.isDeleted && store.isInMonth(o.date, now)).toList();
    final income = monthOps.where((o) => o.type == 'income').fold<double>(0, (s, o) => s + o.amount);
    final expense = monthOps.where((o) => o.type == 'expense').fold<double>(0, (s, o) => s + o.amount);
    if (income == 0 && expense == 0) return const SizedBox.shrink();

    final catTotals = store.categories
        .where((c) => c.type == 'expense')
        .map((c) => (category: c, total: monthOps.where((o) => o.categoryId == c.id && o.type == 'expense').fold<double>(0, (s, o) => s + o.amount)))
        .where((e) => e.total > 0)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final chartPalette = [AppColors.expense, const Color(0xFF1E88E5), AppColors.warning, const Color(0xFF8E24AA), const Color(0xFF00ACC1)];
    final chartSlices = <({String label, double value, Color color})>[];
    for (int i = 0; i < catTotals.length && i < 5; i++) {
      chartSlices.add((label: tCat(context, catTotals[i].category.name), value: catTotals[i].total, color: chartPalette[i % chartPalette.length]));
    }
    final otherTotal = catTotals.length > 5 ? catTotals.skip(5).fold<double>(0, (s, e) => s + e.total) : 0.0;
    if (otherTotal > 0) chartSlices.add((label: context.tr('reports.other'), value: otherTotal, color: AppColors.textSecondary));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('reports.title'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            children: [
              if (chartSlices.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
                  child: SimplePieChart(slices: chartSlices, size: 160, holeRadius: 0.55, showPercentages: true),
                ),
                const SizedBox(height: 8),
                ...chartSlices.take(4).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/operations', arguments: {
                      'categoryId': catTotals.where((c) => tCat(context, c.category.name) == s.label).firstOrNull?.category.id,
                      'dateFrom': DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10),
                      'dateTo': DateTime(now.year, now.month + 1, 0).toIso8601String().substring(0, 10),
                    }),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.label, style: TextStyle(fontSize: 13, color: AppColors.textFor(context)))),
                        Text(store.fmt(s.value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                      ],
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
