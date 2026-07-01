import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../services/update_service.dart';
import '../../theme/theme.dart';
import '../planned_payments/planned_payments_screen.dart';
import '../bank/bank_screen.dart';
import '../categories/categories_screen.dart';
import '../tags/tags_screen.dart';
import '../debug/debug_screen.dart';
import '../recommendations/recommendations_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/profile_screen.dart';
import '../ai_assistant/ai_assistant_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  bool _checking = false;

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    await UpdateService.checkAndShow(context);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.calendar_today, context.tr('more.planned_payments'), const PlannedPaymentsScreen()),
      (Icons.category_outlined, context.tr('more.categories'), const CategoriesScreen()),
      (Icons.account_balance, context.tr('more.easybank'), const BankScreen()),
      (Icons.lightbulb_outline, context.tr('more.recommendations'), const RecommendationsScreen()),
      (Icons.label_outline, context.tr('more.tags'), const TagsScreen()),
      (Icons.system_update_outlined, 'Обновление', null),
      (Icons.settings_outlined, context.tr('more.settings'), const SettingsScreen()),
      (Icons.person_outline, context.tr('more.profile'), const ProfileScreen()),
      (Icons.smart_toy_outlined, context.tr('more.ai_assistant'), const AiAssistantScreen()),
      (Icons.bug_report_outlined, 'Debug API', const DebugScreen()),
    ];

    return ScreenScaffold(
      title: context.tr('more.title'),
      child: Column(
        children: [
          ScreenHint(hintId: 'more', text: 'Настройки, категории, теги, синхронизация и профиль. Здесь же можно проверить обновления приложения.'),
          ...items.map((item) {
          final (icon, title, screen) = item;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: InkWell(
                onTap: screen != null
                    ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
                    : _checking ? null : _checkUpdate,
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.primary, size: 24),
                    const SizedBox(width: 16),
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                    const Spacer(),
                    if (_checking && screen == null)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    else
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
