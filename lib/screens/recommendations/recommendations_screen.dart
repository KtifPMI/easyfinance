import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../budget/add_budget_screen.dart';
import '../goals/add_goal_screen.dart';

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: context.tr('recommendations.title'),
          child: Column(
            children: store.recommendations.map((r) {
              Color color;
              IconData icon;
              switch (r.type) {
                case 'risk':
                  color = AppColors.danger;
                  icon = Icons.warning_amber;
                  break;
                case 'optimization':
                  color = AppColors.warning;
                  icon = Icons.trending_down;
                  break;
                default:
                  color = AppColors.success;
                  icon = Icons.lightbulb_outline;
              }

              final title = context.tr(r.titleKey, namedArgs: r.titleArgs);
              final desc = context.tr(r.descKey, namedArgs: r.descArgs);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                            const SizedBox(height: 4),
                            Text(desc, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                            if (r.actionType != null) ...[
                              const SizedBox(height: 8),
                              _ActionButton(r: r, store: store),
                            ],
                          ],
                        ),
                      ),
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
}

class _ActionButton extends StatelessWidget {
  final dynamic r;
  final FinanceStore store;
  const _ActionButton({required this.r, required this.store});

  @override
  Widget build(BuildContext context) {
    String label;
    VoidCallback? onTap;

    switch (r.actionType) {
      case 'create_budget':
        label = context.tr('recommend.action.create_budget');
        onTap = () {
          final catId = r.actionPayload as String?;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => AddBudgetScreen(categoryId: catId),
          ));
        };
        break;
      case 'create_goal':
        label = context.tr('recommend.action.create_goal');
        onTap = () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => const AddGoalScreen(),
          ));
        };
        break;
      default:
        return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.add, size: 16, color: AppColors.primary),
      label: Text(label, style: TextStyle(fontSize: 13, color: AppColors.primary)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        side: BorderSide(color: AppColors.primary),
      ),
    );
  }
}
