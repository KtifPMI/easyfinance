import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: 'Рекомендации',
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
                            Text(r.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                            const SizedBox(height: 4),
                            Text(r.description, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
