import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/progress_bar.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/calc.dart';
import '../../utils/format.dart';
import '../goals/goal_detail_screen.dart';
import '../goals/add_goal_screen.dart';
import 'budget_detail_screen.dart';
import 'add_budget_screen.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: 'Бюджет и цели',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Бюджет', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
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
                            Text('${formatMoney(b.spent)} / ${formatMoney(b.limit)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                  Text('Цели', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
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
                                  Text('${formatMoney(g.currentAmount)} / ${formatMoney(g.targetAmount)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ProgressBar(percent: percent, color: _parseColor(g.color)),
                        const SizedBox(height: 4),
                        Text('${percent.round()}%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
