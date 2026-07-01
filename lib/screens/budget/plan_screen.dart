import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/progress_bar.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/goal.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/calc.dart';
import '../../utils/format.dart';
import '../goals/add_goal_screen.dart';
import 'add_budget_screen.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: context.tr('budget.title'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHint(hintId: 'plan', text: 'Бюджеты и цели. Установите лимит по категории (например, «Продукты» — 30 000 ₽), чтобы следить за перерасходом. Цели помогут копить на крупные покупки.'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('budget.budget'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBudgetScreen())),
                    child: Icon(Icons.add_circle_outline, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...store.budgets.map((b) {
                final cat = store.getCategory(b.categoryId);
                final percent = getBudgetPercent(b);
                final color = _parseColor(cat?.color ?? '#6B7280');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(b.name ?? cat?.name ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${formatMoney(b.spent)} / ${formatMoney(b.limit)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(context.tr('budget.confirm_delete')),
                                        content: Text(b.name ?? cat?.name ?? ''),
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
                                  child: Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ProgressBar(percent: percent, color: color),
                        const SizedBox(height: 4),
                        Text('${percent.round()}%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('budget.goals'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGoalScreen())),
                    child: Icon(Icons.add_circle_outline, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...store.goals.map((g) {
                final percent = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount * 100) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                                  Text(g.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  if (g.isCompleted)
                                    Text(context.tr('goals.achieved'), style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600))
                                  else
                                    Text('${formatMoney(g.currentAmount)} / ${formatMoney(g.targetAmount)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            if (!g.isCompleted)
                              GestureDetector(
                                onTap: () => _showDepositDialog(context, g, store),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                                  child: Text(context.tr('goals.top_up'), style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ProgressBar(percent: g.isCompleted ? 100 : percent, color: g.isCompleted ? AppColors.success : _parseColor(g.color)),
                        const SizedBox(height: 4),
                        Text(g.isCompleted ? '100%' : '${percent.round()}%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
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
                items: store.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${formatMoney(a.balance)})'))).toList(),
                onChanged: (v) => setDState(() => accountId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('goals.cancel'))),
            TextButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
                if (amount > 0 && accountId != null) {
                  store.depositToGoal(goal.id, amount, accountId!);
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

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
