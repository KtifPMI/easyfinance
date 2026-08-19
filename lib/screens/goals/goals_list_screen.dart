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
                    final balances = {for (final a in store.accounts) a.id: store.accountActualBalance(a)};
                    final bal = g.balanceFrom(balances);
                    final achieved = g.achieved(balances);
                    final percent = achieved ? 100.0 : g.percent(balances);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddGoalScreen(goalId: g.id))),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: achieved ? AppColors.success.withValues(alpha: 0.15) : _parseColor(g.color).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    achieved ? Icons.emoji_events : _goalIcon(g.icon),
                                    color: achieved ? AppColors.success : _parseColor(g.color),
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
                                          Expanded(child: Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context)))),
                                          if (achieved) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                              child: Text(context.tr('goals.achieved'), style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (achieved)
                                        Text(context.tr('goals.achieved_title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppColors.success))
                                      else
                                        Text('${store.fmt(bal)} / ${store.fmt(g.targetAmount)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  onPressed: () => _confirmDelete(context, g, store),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ProgressBar(percent: achieved ? 100 : percent, color: achieved ? AppColors.success : _parseColor(g.color)),
                            const SizedBox(height: 4),
                              if (achieved)
                                Text('100%', style: TextStyle(fontSize: 12, color: AppColors.success))
                            else
                              Text('${percent.round()}% · ${context.tr('goals.deadline')} ${g.deadline.isNotEmpty ? formatDateLong(g.deadline) : context.tr('goals.no_deadline')}', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                              if (!achieved && g.monthlyRecommendation != null && g.monthlyRecommendation! > 0) ...[
                              const SizedBox(height: 4),
                              Text(context.tr('goals.recommendation', namedArgs: {'amount': store.fmt(g.monthlyRecommendation!)}), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                            ],
                          ],
                        ),
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

  IconData _goalIcon(String name) {
    const map = {'shield': Icons.shield, 'beach_access': Icons.beach_access, 'laptop': Icons.laptop, 'star': Icons.star};
    return map[name] ?? Icons.star;
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
