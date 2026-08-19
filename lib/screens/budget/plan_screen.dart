import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/progress_bar.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/budget.dart';
import '../../models/goal.dart';
import '../../store/finance_store.dart';
import '../../utils/input_formatters.dart';
import '../../theme/theme.dart';
import '../../utils/calc.dart';
import '../../utils/translate_category.dart';
import '../../utils/category_icons.dart';
import '../goals/add_goal_screen.dart';
import 'add_budget_screen.dart';

class PlanScreen extends StatefulWidget {
  final bool scrollToGoals;
  const PlanScreen({super.key, this.scrollToGoals = false});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    if (widget.scrollToGoals) {
      _tabCtrl.animateTo(1);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: context.tr('budget.title'),
          forceLogo: true,
          onRefresh: () => store.fetchAllData(),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddChoice(context),
            child: const Icon(Icons.add),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardFor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondaryFor(context),
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    Tab(text: context.tr('budget.budget')),
                    Tab(text: context.tr('budget.goals')),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildBudgetsTab(context, store),
                    _buildGoalsTab(context, store),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetsTab(BuildContext context, FinanceStore store) {
    final incomeBudgets = store.budgets.where((b) {
      final cat = store.getCategory(b.categoryId);
      return cat != null && cat.type == 'income';
    }).toList()..sort((a, b) => b.limit.compareTo(a.limit));

    final expenseBudgets = store.budgets.where((b) {
      final cat = store.getCategory(b.categoryId);
      return cat == null || cat.type != 'income';
    }).toList()..sort((a, b) => b.limit.compareTo(a.limit));

    final incomePlanned = incomeBudgets.fold(0.0, (s, b) => s + b.limit);
    final expensePlanned = expenseBudgets.fold(0.0, (s, b) => s + b.limit);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incomeBudgets.isNotEmpty || expenseBudgets.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(context.tr('budget.monthly_summary'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (incomeBudgets.isNotEmpty) ...[
                    Text(context.tr('budget.income'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.income)),
                    const SizedBox(height: 4),
                    _summaryRow(context, 'budget.planned', store.fmt(incomePlanned)),
                    _summaryRow(context, 'budget.received', store.fmt(store.monthIncome), AppColors.success),
                    _summaryRow(context, 'budget.remaining', store.fmt(incomePlanned - store.monthIncome), (incomePlanned - store.monthIncome) >= 0 ? AppColors.success : AppColors.expense),
                    const SizedBox(height: 12),
                  ],
                  if (expenseBudgets.isNotEmpty) ...[
                    Text(context.tr('budget.expense'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.expense)),
                    const SizedBox(height: 4),
                    _summaryRow(context, 'budget.planned', store.fmt(expensePlanned)),
                    _summaryRow(context, 'budget.spent_total', store.fmt(store.monthExpense), store.monthExpense > expensePlanned ? AppColors.expense : null),
                    _summaryRow(context, 'budget.remaining', store.fmt(expensePlanned - store.monthExpense), (expensePlanned - store.monthExpense) >= 0 ? AppColors.success : AppColors.expense),
                    const SizedBox(height: 12),
                  ],
                  Text(context.tr('budget.net_income'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                  const SizedBox(height: 4),
                  _summaryRow(context, 'budget.planned', store.fmt(incomePlanned - expensePlanned)),
                  _summaryRow(context, 'budget.received', store.fmt(store.monthIncome - store.monthExpense), AppColors.success),
                  _summaryRow(context, 'budget.remaining', store.fmt((incomePlanned - expensePlanned) - (store.monthIncome - store.monthExpense)), ((incomePlanned - expensePlanned) - (store.monthIncome - store.monthExpense)) >= 0 ? AppColors.success : AppColors.expense),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (incomeBudgets.isNotEmpty) ...[
            Text(context.tr('budget.income'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.income)),
            const SizedBox(height: 8),
            ...incomeBudgets.map((b) => _budgetItem(context, b, store)),
            const SizedBox(height: 12),
          ],

          if (expenseBudgets.isNotEmpty) ...[
            Text(context.tr('budget.expense'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.expense)),
            const SizedBox(height: 8),
            ...expenseBudgets.map((b) => _budgetItem(context, b, store)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String labelKey, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.tr(labelKey), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? AppColors.textFor(context))),
        ],
      ),
    );
  }

  Widget _budgetItem(BuildContext context, Budget b, FinanceStore store) {
    final cat = store.getCategory(b.categoryId);
    final forecastPct = getBudgetForecastPercent(b);
    final color = budgetForecastColor(forecastPct);
    final spentPct = b.limit > 0 ? (b.spent / b.limit * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _editBudgetDialog(context, b, store),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (cat != null) ...[
                    Icon(categoryIconFor(cat, allCategories: store.categories), size: 18, color: cat.type == 'income' ? AppColors.income : AppColors.expense),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(b.name ?? tCat(context, cat?.name ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text('${store.fmt(b.spent)} / ${store.fmt(b.limit)}', maxLines: 1, softWrap: false, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          title: Text(context.tr('budget.confirm_delete')),
                          content: Text(b.name ?? tCat(context, cat?.name ?? '')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('budget.cancel'))),
                            TextButton(
                              onPressed: () {
                                store.deleteBudget(b.id);
                                Navigator.pop(ctx);
                              },
                              child: Text(context.tr('budget.delete'), style: TextStyle(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondaryFor(context)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProgressBar(percent: spentPct, color: color),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('budget.forecast'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                  Text('${forecastPct.round()}%', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalsTab(BuildContext context, FinanceStore store) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ...store.goals.map((g) {
            final balances = {for (final a in store.accounts) a.id: store.accountActualBalance(a)};
            final bal = g.balanceFrom(balances);
            final achieved = g.achieved(balances);
            final percent = achieved ? 100.0 : (g.targetAmount > 0 ? (bal / g.targetAmount * 100) : 0.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddGoalScreen(goalId: g.id))),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_goalIcon(g.icon), color: _parseColor(g.color), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                if (achieved)
                                  Text(context.tr('goals.achieved'), style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600))
                                else
                                  Text('${store.fmt(bal)} / ${store.fmt(g.targetAmount)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            onPressed: () => _confirmDelete(context, g, store),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ProgressBar(percent: achieved ? 100 : percent, color: achieved ? AppColors.success : _parseColor(g.color)),
                      const SizedBox(height: 4),
                      Text(achieved ? '100%' : '${percent.round()}%', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  IconData _goalIcon(String name) {
    const map = {'shield': Icons.shield, 'beach_access': Icons.beach_access, 'laptop': Icons.laptop, 'star': Icons.star};
    return map[name] ?? Icons.star;
  }



  void _confirmDelete(BuildContext context, Goal goal, FinanceStore store) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('goals.delete_title')),
        content: Text(context.tr('goals.delete_confirm', namedArgs: {'title': goal.title})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('goals.cancel'))),
          TextButton(
            onPressed: () {
              store.deleteGoal(goal.id);
              Navigator.pop(ctx);
            },
            child: Text(context.tr('goals.delete'), style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _showAddChoice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: AppColors.primary),
              title: Text(context.tr('budget.add_budget')),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBudgetScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.flag, color: AppColors.primary),
              title: Text(context.tr('goals.add_goal')),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGoalScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editBudgetDialog(BuildContext context, Budget b, FinanceStore store) {
    final limitCtrl = TextEditingController(text: b.limit.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('budget.edit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(b.name ?? store.getCategory(b.categoryId)?.name ?? '', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorFormatter()],
              decoration: InputDecoration(labelText: context.tr('budget.limit_label')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('budget.cancel'))),
          TextButton(
            onPressed: () async {
              final newLimit = double.tryParse(limitCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
              if (newLimit <= 0) return;
              await store.updateBudget(b.copyWith(limit: newLimit));
              if (!ctx.mounted) return;
              if (store.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!), backgroundColor: AppColors.danger));
                return;
              }
              Navigator.pop(ctx);
            },
            child: Text(context.tr('budget.save')),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
