import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/progress_bar.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/goal.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import 'add_goal_screen.dart';

class GoalsListScreen extends StatelessWidget {
  const GoalsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: context.tr('goals.title'),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGoalScreen())),
            child: const Icon(Icons.add),
          ),
          onRefresh: () => store.fetchAllData(),
          child: store.goals.isEmpty
              ? Center(child: Text(context.tr('goals.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context))))
              : Column(
                  children: store.goals.map((g) {
                    final percent = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount * 100) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: g.isCompleted ? AppColors.success.withValues(alpha: 0.15) : _parseColor(g.color).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    g.isCompleted ? Icons.emoji_events : _goalIcon(g.icon),
                                    color: g.isCompleted ? AppColors.success : _parseColor(g.color),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: Text(g.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context)))),
                                          if (g.isCompleted)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                              child: Text(context.tr('goals.achieved'), style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (g.isCompleted)
                                        Text(context.tr('goals.achieved_title'), style: TextStyle(fontSize: 13, color: AppColors.success))
                                      else
                                        Text('${store.fmt(g.currentAmount)} / ${store.fmt(g.targetAmount)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
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
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  onPressed: () => _confirmDelete(context, g, store),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ProgressBar(percent: g.isCompleted ? 100 : percent, color: g.isCompleted ? AppColors.success : _parseColor(g.color)),
                            const SizedBox(height: 4),
                            if (g.isCompleted)
                              Text('100%', style: TextStyle(fontSize: 11, color: AppColors.success))
                            else
                              Text('${percent.round()}% · ${context.tr('goals.deadline')} ${g.deadline.isNotEmpty ? formatDateLong(g.deadline) : 'Без срока'}', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryFor(context))),
                            if (!g.isCompleted && g.monthlyRecommendation != null && g.monthlyRecommendation! > 0) ...[
                              const SizedBox(height: 4),
                              Text(context.tr('goals.recommendation', namedArgs: {'amount': store.fmt(g.monthlyRecommendation!)}), style: TextStyle(fontSize: 11, color: AppColors.textSecondaryFor(context))),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Goal goal, FinanceStore store) {
    showDialog(
      context: context,
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

  IconData _goalIcon(String name) {
    const map = {'shield': Icons.shield, 'beach_access': Icons.beach_access, 'laptop': Icons.laptop, 'star': Icons.star};
    return map[name] ?? Icons.star;
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
