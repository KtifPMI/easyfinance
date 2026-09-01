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
import '../../utils/color_utils.dart';
import '../../utils/translate_category.dart';
import '../../utils/category_icons.dart';
import '../../utils/planned_event_title.dart';
import '../../components/common/simple_pie_chart.dart';
import '../../store/planned_payment_store.dart';
import '../../services/currency_rate_service.dart';
import '../accounts/add_account_screen.dart';
import '../accounts/accounts_screen.dart';
import '../budget/plan_screen.dart';
import '../recommendations/recommendations_screen.dart';
import '../reports/reports_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _plannedSynced = false;
  bool _goalsSynced = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<FinanceStore, PlannedPaymentStore>(
      builder: (context, store, plannedPayments, _) {
        if (!_plannedSynced) {
          _plannedSynced = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            plannedPayments.syncFromServer();
          });
        }
        if (!_goalsSynced) {
          _goalsSynced = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            store.refreshGoals();
          });
        }
        final indicators = calcFinHealth(store.accounts, store.operations, store.budgets, store.rates);
        final accountType = store.currentUser?.accountType ?? 'individual';

        return ScreenScaffold(
          title: '',
          showLogo: false,
          titleWidget: Row(
            children: [
              Container(
                height: 42,
                margin: const EdgeInsets.only(left: -8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardFor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: AppLogo(height: 26)),
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
                          child:                          const Icon(Icons.send, size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          isLoading: store.isLoading && store.accounts.isEmpty && store.operations.isEmpty,
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
              _statLine(context.tr('home.expense'), store.fmt(store.monthExpense), AppColors.expense, alignment: Alignment.centerRight),
            ]),
            const SizedBox(height: 8),
            _statLine(context.tr('home.profit'), store.fmt(savings), Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _statLine(String label, String amount, Color color, {Alignment alignment = Alignment.centerLeft}) {
    return Expanded(
      child: Align(
        alignment: alignment,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Text(amount, style: TextStyle(color: color == Colors.white ? const Color(0xFF0F2A14) : Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }


  Widget _buildRestSkeleton(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                    decoration: BoxDecoration(color: parseColor(a.color).withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(iconMap[a.icon] ?? Icons.account_balance, color: parseColor(a.color)),
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
                  Text(currencySymbol(code), style: TextStyle(fontSize: 17)),
                  const SizedBox(width: 8),
                  Text(code, style: TextStyle(fontSize: 16)),
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

    final expenseBudgets = store.budgets.where((b) {
      final cat = store.getCategory(b.categoryId);
      return cat == null || cat.type != 'income';
    }).toList();
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysPassed = now.day.clamp(1, daysInMonth);
    final totalPlanned = expenseBudgets.fold(0.0, (sum, b) => sum + b.limit);
    final totalSpent = store.monthExpense;
    final totalRemaining = totalPlanned - totalSpent;
    final forecastedSpend = (daysPassed > 0 && totalSpent > 0) ? totalSpent / daysPassed * daysInMonth : 0.0;
    final budgetForecastPct = totalPlanned > 0 ? (forecastedSpend / totalPlanned * 100) : 0.0;
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
    // Same balance resolution as the goal screen: sum the linked accounts'
    // actual balances (falls back to stored currentAmount when no accounts are
    // linked), so the home card matches the goal settings screen.
    final balances = {for (final a in store.accounts) a.id: store.accountActualBalance(a)};
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
          final bal = g.balanceFrom(balances);
          final percent = g.targetAmount > 0 ? (bal / g.targetAmount * 100) : 0.0;
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
                  ProgressBar(percent: percent, color: parseColor(g.color)),
                  Text('${store.fmt(bal)} / ${store.fmt(g.targetAmount)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = plannedPayments.overdueEvents;
    final upcoming = plannedPayments.upcomingEvents.where((e) {
      final next = e.nextOccurrence();
      return next == null || !e.isAcceptedOn('${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}');
    }).toList();
    final combined = <FinancialEvent>[...overdue, ...upcoming];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/calendar'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('home.upcoming_payments'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (combined.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.tr('calendar.empty'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          )
        else
          ...combined.take(8).map((e) {
            final isOverdue = overdue.contains(e);
            final displayDate = isOverdue ? (e.lastOccurrence(before: today) ?? today) : (e.nextOccurrence() ?? today);
            return GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/calendar'),
              child: _upcomingTile(context, e, store, displayDate: displayDate, isOverdue: isOverdue),
            );
          }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _upcomingTile(BuildContext context, FinancialEvent e, FinanceStore store, {required DateTime displayDate, bool isOverdue = false}) {
    final cat = e.categoryId != null ? store.getCategory(e.categoryId) : null;
    final iconData = cat != null ? categoryIconFor(cat, allCategories: store.categories) : (e.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward);
    final iconColor = e.type == 'income' ? AppColors.success : AppColors.expense;
    final amountColor = isOverdue ? AppColors.danger : iconColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: isOverdue ? AppColors.danger.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(16),
          border: isOverdue ? Border.all(color: AppColors.danger.withValues(alpha: 0.3), width: 1.5) : null,
        ),
        child: AppCard(
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (isOverdue ? AppColors.danger : iconColor).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(isOverdue ? Icons.warning_amber_rounded : iconData, size: 20, color: isOverdue ? AppColors.danger : iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plannedEventTitle(e, store), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                    Row(
                      children: [
                        Text(formatDate(_fmtDate(displayDate)), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                        if (isOverdue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(6)),
                            child: Text(context.tr('calendar.overdue'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(store.fmt(e.amount), maxLines: 1, softWrap: false, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: amountColor)),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildReportsSection(BuildContext context, FinanceStore store) {
    final now = DateTime.now();
    final monthOps = store.operations.where((o) => !o.isDeleted && store.isInMonth(o.date, now)).toList();
    double amtRub(o) {
      final acc = store.getAccount(o.accountId);
      final from = acc?.currency ?? o.currency;
      return CurrencyRateService.convert(o.amount, from, 'RUB', store.rates);
    }
    final catTotals = store.categories
        .where((c) => c.type == 'expense')
        .map((c) => (category: c, total: monthOps.where((o) => o.categoryId == c.id).fold<double>(0, (s, o) => s + amtRub(o))))
        .where((e) => e.total > 0)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    if (catTotals.isEmpty) return const SizedBox.shrink();

    final catExpense = catTotals.fold<double>(0, (s, e) => s + e.total);
    final otherTotal = catTotals.length > 6 ? catTotals.skip(6).fold<double>(0, (s, e) => s + e.total) : 0.0;
    final palette = const [
      Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00),
      Color(0xFF8E24AA), Color(0xFF00ACC1), Color(0xFFF4511E), Color(0xFF3949AB),
      Color(0xFFD81B60), Color(0xFF7CB342), Color(0xFF6D4C41), Color(0xFFC0CA33),
      Color(0xFFFF7043), Color(0xFF26A69A), Color(0xFF5C6BC0), Color(0xFFAB47BC),
    ];
    final chartSlices = <({String label, double value, Color color})>[];
    for (int i = 0; i < catTotals.length && i < 6; i++) {
      chartSlices.add((label: tCat(context, catTotals[i].category.name), value: catTotals[i].total, color: palette[i % palette.length]));
    }
    if (otherTotal > 0) {
      chartSlices.add((label: context.tr('reports.other'), value: otherTotal, color: const Color(0xFF9E9E9E)));
    }

    final top = catTotals.take(6).toList();

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
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
                child: SimplePieChart(slices: chartSlices, size: 220, holeRadius: 0.5, showPercentages: true),
              ),
              const SizedBox(height: 12),
              ...top.map((e) {
                final percent = catExpense > 0 ? e.total / catExpense * 100 : 0.0;
                final color = palette[top.indexOf(e) % palette.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(tCat(context, e.category.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: AppColors.textFor(context)))),
                            const SizedBox(width: 8),
                            Text('${percent.round()}% · ${store.fmt(e.total)}', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(height: 6, color: AppColors.borderFor(context), child: FractionallySizedBox(widthFactor: percent / 100, child: Container(color: color))),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (otherTotal > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(context.tr('reports.other'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: AppColors.textSecondaryFor(context)))),
                      const SizedBox(width: 8),
                      Text('${catExpense > 0 ? (otherTotal / catExpense * 100).round() : 0}% · ${store.fmt(otherTotal)}', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
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
}
