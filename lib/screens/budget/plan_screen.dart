import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/progress_bar.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/budget.dart';
import '../../models/goal.dart';
import '../../store/finance_store.dart';
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
        final totalPlanned = store.budgets.fold(0.0, (sum, b) => sum + b.limit);
        final totalSpent = store.budgets.fold(0.0, (sum, b) => sum + b.spent);
        final budgetPercent = totalPlanned > 0 ? (totalSpent / totalPlanned * 100).clamp(0.0, 100.0) : 0.0;
        final monthIncome = store.monthIncome;
        final monthExpense = store.monthExpense;

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
                    _buildBudgetsTab(context, store, totalPlanned, totalSpent, budgetPercent, monthIncome, monthExpense),
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

  Widget _buildBudgetsTab(BuildContext context, FinanceStore store, double totalPlanned, double totalSpent, double budgetPercent, double monthIncome, double monthExpense) {
    final incomeBudgets = store.budgets.where((b) {
      final cat = store.getCategory(b.categoryId);
      return cat != null && cat.type == 'income';
    }).toList()..sort((a, b) => b.limit.compareTo(a.limit));

    final expenseBudgets = store.budgets.where((b) {
      final cat = store.getCategory(b.categoryId);
      return cat == null || cat.type != 'income';
    }).toList()..sort((a, b) => b.limit.compareTo(a.limit));

    final incomePlanned = incomeBudgets.fold(0.0, (s, b) => s + b.limit);
    final incomeSpent = incomeBudgets.fold(0.0, (s, b) => s + b.spent);
    final expensePlanned = expenseBudgets.fold(0.0, (s, b) => s + b.limit);
    final expenseSpent = expenseBudgets.fold(0.0, (s, b) => s + b.spent);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (monthIncome > 0 || monthExpense > 0) ...[
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _statBlock(context, context.tr('budget.income'), store.fmt(monthIncome), AppColors.income)),
                      const SizedBox(width: 12),
                      Expanded(child: _statBlock(context, context.tr('budget.expense'), store.fmt(monthExpense), AppColors.expense)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (incomeBudgets.isNotEmpty) ...[
                    Text(context.tr('budget.income'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.income)),
                    const SizedBox(height: 4),
                    _summaryRow(context, 'budget.planned', store.fmt(incomePlanned)),
                    _summaryRow(context, 'budget.received', store.fmt(incomeSpent), AppColors.success),
                    if (incomePlanned > incomeSpent)
                      _summaryRow(context, 'budget.under_received', store.fmt(incomePlanned - incomeSpent), AppColors.warning),
                    const SizedBox(height: 12),
                  ],
                  if (expenseBudgets.isNotEmpty) ...[
                    Text(context.tr('budget.expense'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.expense)),
                    const SizedBox(height: 4),
                    _summaryRow(context, 'budget.planned', store.fmt(expensePlanned)),
                    _summaryRow(context, 'budget.spent_total', store.fmt(expenseSpent), expenseSpent > expensePlanned ? AppColors.expense : null),
                    _summaryRow(context, 'budget.remaining', store.fmt(expensePlanned - expenseSpent), (expensePlanned - expenseSpent) >= 0 ? AppColors.success : AppColors.expense),
                  ],
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
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 4,
                  color: AppColors.borderFor(context),
                  child: FractionallySizedBox(
                    widthFactor: (forecastPct / 100).clamp(0.0, 1.0),
                    child: Container(color: color),
                  ),
                ),
              ),
              const SizedBox(height: 4),
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
            final percent = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount * 100) : 0.0;
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
                                if (g.isCompleted)
                                  Text(context.tr('goals.achieved'), style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600))
                                else
                                  Text('${store.fmt(g.currentAmount)} / ${store.fmt(g.targetAmount)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!g.isCompleted)
                            GestureDetector(
                              onTap: () => _showDepositDialog(context, g, store),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                                child: Text(context.tr('goals.top_up'), style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
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
                      ProgressBar(percent: g.isCompleted ? 100 : percent, color: g.isCompleted ? AppColors.success : _parseColor(g.color)),
                      const SizedBox(height: 4),
                      Text(g.isCompleted ? '100%' : '${percent.round()}%', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
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

  void _showDepositDialog(BuildContext context, Goal goal, FinanceStore store) {
    final amountCtrl = TextEditingController();
    String? accountId = store.accounts.isNotEmpty ? store.accounts.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(goal.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.tr('goals.amount')),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                decoration: InputDecoration(labelText: context.tr('goals.from_account')),
                items: store.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${store.fmt(a.balance, fromCurrency: a.currency)})'))).toList(),
                onChanged: (v) => setDState(() => accountId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('goals.cancel'))),
            TextButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
                if (amount > 0 && accountId != null) {
                  await store.depositToGoal(goal.id, amount, accountId!);
                  if (!ctx.mounted) return;
                  if (store.error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!), backgroundColor: AppColors.danger));
                    return;
                  }
                  final newGoal = store.goals.where((g) => g.id == goal.id).firstOrNull;
                  if (newGoal != null && newGoal.isCompleted) {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(context.tr('goals.congrats')),
                        content: Text(context.tr('goals.achieved_text', namedArgs: {'title': goal.title})),
                        actions: [TextButton(onPressed: () => Navigator.pop(_), child: Text(context.tr('goals.ok')))],
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                }
              },
              child: Text(context.tr('goals.top_up')),
            ),
          ],
        ),
      ),
    );
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
              decoration: InputDecoration(labelText: context.tr('budget.limit_label')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('budget.cancel'))),
          TextButton(
            onPressed: () async {
              final newLimit = double.tryParse(limitCtrl.text.replaceAll(',', '.')) ?? 0;
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

  void _editGoalDialog(BuildContext context, Goal g, FinanceStore store) {
    final titleCtrl = TextEditingController(text: g.title);
    final totalCtrl = TextEditingController(text: g.targetAmount.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('goals.edit_goal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: context.tr('goals.goal_title'))),
            const SizedBox(height: 12),
            TextField(controller: totalCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.tr('goals.goal_amount'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('goals.cancel'))),
          TextButton(
            onPressed: () async {
              final newTotal = double.tryParse(totalCtrl.text.replaceAll(',', '.')) ?? 0;
              final newTitle = titleCtrl.text.trim();
              if (newTotal <= 0 || newTitle.isEmpty) return;
              await store.updateGoal(g.id, currentAmount: g.currentAmount, isCompleted: g.isCompleted, title: newTitle, targetAmount: newTotal);
              if (!ctx.mounted) return;
              if (store.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!), backgroundColor: AppColors.danger));
                return;
              }
              Navigator.pop(ctx);
            },
            child: Text(context.tr('goals.save')),
          ),
        ],
      ),
    );
  }

  void _copyBudgets(BuildContext context, FinanceStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('budget.copy_month')),
        content: Text(context.tr('budget.copy_month_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('budget.cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final b in store.budgets) {
                store.addBudget(Budget(
                  id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
                  categoryId: b.categoryId,
                  limit: b.limit,
                  name: b.name,
                ));
              }
            },
            child: Text(context.tr('budget.copy'), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Widget _statBlock(BuildContext context, String label, String formattedAmount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
        const SizedBox(height: 4),
        Text(formattedAmount, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
