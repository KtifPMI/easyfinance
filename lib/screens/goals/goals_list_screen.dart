import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/progress_bar.dart';
import '../../components/common/screen_scaffold.dart';
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
                                  decoration: BoxDecoration(color: _parseColor(g.color).withValues(alpha: 0.15), shape: BoxShape.circle),
                                  child: Icon(_goalIcon(g.icon), color: _parseColor(g.color), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(g.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                                      const SizedBox(height: 4),
                                      Text('${formatMoney(g.currentAmount)} / ${formatMoney(g.targetAmount)}', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ProgressBar(percent: percent, color: _parseColor(g.color)),
                            const SizedBox(height: 4),
                            Text('${percent.round()}% · срок ${formatDateLong(g.deadline)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            if (g.monthlyRecommendation != null && g.monthlyRecommendation! > 0) ...[
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

  IconData _goalIcon(String name) {
    const map = {'shield': Icons.shield, 'beach_access': Icons.beach_access, 'laptop': Icons.laptop, 'star': Icons.star};
    return map[name] ?? Icons.star;
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
