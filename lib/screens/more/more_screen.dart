import 'package:flutter/material.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';
import '../bank/bank_screen.dart';
import '../recommendations/recommendations_screen.dart';
import '../informer/informer_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/profile_screen.dart';
import '../ai_assistant/ai_assistant_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.account_balance, 'EasyBank', const BankScreen()),
      (Icons.lightbulb_outline, 'Рекомендации', const RecommendationsScreen()),
      (Icons.info_outline, 'Информер', const InformerScreen()),
      (Icons.settings_outlined, 'Настройки', const SettingsScreen()),
      (Icons.person_outline, 'Профиль', const ProfileScreen()),
      (Icons.smart_toy_outlined, 'ИИ-ассистент', const AiAssistantScreen()),
    ];

    return ScreenScaffold(
      title: 'Ещё',
      child: Column(
        children: items.map((item) {
          final (icon, title, screen) = item;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 24),
                    const SizedBox(width: 16),
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
