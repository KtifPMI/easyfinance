import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';
import '../accounts/accounts_screen.dart';
import '../planned_payments/planned_payments_screen.dart';
import '../debug/debug_screen.dart';
import '../recommendations/recommendations_screen.dart';
import '../settings/settings_screen.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../templates/templates_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.calendar_today, context.tr('more.planned_payments'), const PlannedPaymentsScreen()),
      (Icons.account_balance, context.tr('more.easybank'), const AccountsScreen()),
      (Icons.lightbulb_outline, context.tr('more.recommendations'), const RecommendationsScreen()),
      (Icons.smart_toy_outlined, context.tr('more.ai_assistant'), const AiAssistantScreen()),
      (Icons.description_outlined, context.tr('templates.title'), const TemplatesScreen()),
      (Icons.settings_outlined, context.tr('more.settings'), const SettingsScreen()),
      (Icons.bug_report_outlined, 'Debug API', const DebugScreen()),
    ];

    return ScreenScaffold(
      title: context.tr('more.title'),
      child: Column(
        children: [
          ScreenHint(hintId: 'more', text: 'Настройки, категории, теги, синхронизация и профиль.'),
          ...items.map((item) {
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
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: AppColors.textSecondaryFor(context)),
                  ],
                ),
              ),
            ),
          );
          }),
        ],
      ),
    );
  }
}
