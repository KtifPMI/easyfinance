import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../services/update_service.dart';
import '../../store/finance_store.dart';
import '../../store/locale_store.dart';
import '../../theme/theme.dart';
import '../categories/categories_screen.dart';
import '../tags/tags_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: context.tr('settings.title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Основные', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _navItem(context, Icons.category_outlined, 'Категории', const CategoriesScreen()),
          _navItem(context, Icons.label_outline, 'Теги', const TagsScreen()),
          _divider(),
          Text('Приложение', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _langItem(context),
          _infoItem(context.tr('settings.about'), 'v$_appVersion'),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: InkWell(
                onTap: () => UpdateService.checkAndShow(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Проверить обновления', style: TextStyle(fontSize: 15, color: AppColors.text)),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          _divider(),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: InkWell(
                onTap: () {
                  final store = context.read<FinanceStore>();
                  store.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                },
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.expense, size: 20),
                    const SizedBox(width: 12),
                    Text('Выйти', style: TextStyle(fontSize: 15, color: AppColors.expense)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String title, Widget screen) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 15, color: AppColors.text)),
              const Spacer(),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 15, color: AppColors.text)),
            Text(value, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
