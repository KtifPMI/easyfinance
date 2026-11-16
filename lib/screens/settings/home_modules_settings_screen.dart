import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/home_modules_prefs.dart';
import '../../theme/theme.dart';

class HomeModulesSettingsScreen extends StatelessWidget {
  const HomeModulesSettingsScreen({super.key});

  static const _items = [
    (HomeModule.finHealth, 'home_settings.fin_health'),
    (HomeModule.rates, 'home_settings.rates'),
    (HomeModule.recommendations, 'home_settings.recommendations'),
    (HomeModule.upcoming, 'home_settings.upcoming'),
    (HomeModule.budgets, 'home_settings.budgets'),
    (HomeModule.goals, 'home_settings.goals'),
    (HomeModule.reports, 'home_settings.reports'),
  ];

  @override
  Widget build(BuildContext context) {
    final modules = context.watch<HomeModulesPrefs>();
    return ScreenScaffold(
      title: context.tr('settings.home_screen'),
      showLogo: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              context.tr('home_settings.intro'),
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.textSecondaryFor(context)),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (final (module, key) in _items)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr(key), style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
                    value: modules.isVisible(module),
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => modules.setVisible(module, v),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
