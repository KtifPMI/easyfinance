import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/locale_store.dart';
import '../../theme/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: context.tr('settings.title'),
      child: Column(
        children: [
          _item(context.tr('settings.currency'), context.tr('settings.currency_value')),
          _langItem(context),
          _item(context.tr('settings.tariff'), context.tr('settings.tariff_free')),
          _item(context.tr('settings.notifications'), context.tr('settings.notifications_on')),
          _divider(),
          _item(context.tr('settings.about'), 'v1.0.0'),
          _item(context.tr('settings.rate'), ''),
          _item(context.tr('settings.help'), ''),
        ],
      ),
    );
  }

  Widget _item(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 15, color: AppColors.text)),
            if (value.isNotEmpty) Text(value, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _langItem(BuildContext context) {
    final currentLocale = context.locale.languageCode;
    final label = currentLocale == 'en'
        ? context.tr('settings.language_en')
        : context.tr('settings.language_ru');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: InkWell(
          onTap: () => _showLangDialog(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('settings.language'), style: TextStyle(fontSize: 15, color: AppColors.text)),
              Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  void _showLangDialog(BuildContext context) {
    final current = context.locale.languageCode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('settings.language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(context.tr('settings.language_ru')),
              leading: Icon(Icons.check_circle, color: current == 'ru' ? AppColors.primary : Colors.transparent),
              onTap: () {
                const locale = Locale('ru');
                context.read<LocaleStore>().setLocale(locale);
                context.setLocale(locale);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text(context.tr('settings.language_en')),
              leading: Icon(Icons.check_circle, color: current == 'en' ? AppColors.primary : Colors.transparent),
              onTap: () {
                const locale = Locale('en');
                context.read<LocaleStore>().setLocale(locale);
                context.setLocale(locale);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1));
}
