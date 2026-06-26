import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          title: 'Цели',
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGoalScreen())),
            ),
          ],
          child: store.goals.isEmpty
              ? Center(child: Text('Нет целей', style: TextStyle(color: AppColors.textSecondary)))
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
                                          Expanded(child: Text(g.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text))),
                                          if (g.isCompleted)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                              child: Text('Достигнута', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (g.isCompleted)
                                        Text('Цель достигнута!', style: TextStyle(fontSize: 13, color: AppColors.success))
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
                                      child: const Text('Пополнить', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ProgressBar(percent: g.isCompleted ? 100 : percent, color: g.isCompleted ? AppColors.success : _parseColor(g.color)),
                            const SizedBox(height: 4),
                            if (g.isCompleted)
                              Text('100%', style: TextStyle(fontSize: 11, color: AppColors.success))
                            else
                              Text('${percent.round()}% · срок ${formatDateLong(g.deadline)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            if (!g.isCompleted && g.monthlyRecommendation != null && g.monthlyRecommendation! > 0) ...[
                              const SizedBox(height: 4),
                              Text('Рекомендуется откладывать ${formatMoney(g.monthlyRecommendation!)} в месяц', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
                decoration: const InputDecoration(labelText: 'Сумма'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: accountId,
                decoration: const InputDecoration(labelText: 'Списать со счёта'),
                items: store.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${formatMoney(a.balance)})'))).toList(),
                onChanged: (v) => setDState(() => accountId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
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
                        title: const Text('Поздравляем!'),
                        content: Text('Цель "${goal.title}" достигнута!'),
                        actions: [TextButton(onPressed: () => Navigator.pop(_), child: const Text('Отлично'))],
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Пополнить'),
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
