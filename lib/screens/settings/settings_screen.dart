import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../components/common/app_card.dart';
import '../../components/common/app_logo.dart';
import '../../components/common/screen_scaffold.dart';
import '../../services/csv_export_service.dart';
import '../../services/update_service.dart';
import '../../store/finance_store.dart';
import '../../store/locale_store.dart';
import '../../store/planned_payment_store.dart';
import '../../store/theme_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../auth/pin_screen.dart';
import 'support_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  bool _pinEnabled = false;
  bool _kopeksEnabled = false;
  bool _kopeksInOpsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadPinStatus();
    _loadKopeksStatus();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  Future<void> _loadPinStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('easyfinance_pin');
    if (mounted) setState(() => _pinEnabled = pin != null && pin.isNotEmpty);
  }

  Future<void> _loadKopeksStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool('easyfinance_show_kopeks') ?? true;
    final opsVal = prefs.getBool('easyfinance_show_kopeks_ops') ?? true;
    showKopeks = val;
    showKopeksInOps = opsVal;
    if (mounted) setState(() { _kopeksEnabled = val; _kopeksInOpsEnabled = opsVal; });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: context.tr('settings.title'),
      showLogo: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileSection(context),
          const SizedBox(height: 8),
          Text(context.tr('settings.app_section'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          _langItem(context),
          _darkModeItem(context),
          _pinItem(context),
          _kopeksItem(context),
          _kopeksInOpsItem(context),
          _startScreenItem(context),
          _infoItem(context.tr('settings.about'), 'v$_appVersion'),
          _exportItem(context),
          _supportItem(context),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: InkWell(
                onTap: () => UpdateService.checkAndShow(context, showLatest: true),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr('settings.check_updates'), style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
                    Icon(Icons.chevron_right, color: AppColors.textSecondaryFor(context)),
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
                onTap: () async {
                  final store = context.read<FinanceStore>();
                  await context.read<PlannedPaymentStore>().clear();
                  await store.logout();
                  if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                },
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.expense, size: 20),
                    const SizedBox(width: 12),
                    Text(context.tr('settings.logout'), style: TextStyle(fontSize: 16, color: AppColors.expense)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Center(child: AppLogo(height: 32)),
          const SizedBox(height: 16),
        ],
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
            Text(title, style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
            Text(value, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          ],
        ),
      ),
    );
  }

  Widget _langItem(BuildContext context) {
    final currentLocale = context.locale.languageCode;
    final label = context.tr('settings.language_$currentLocale');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: InkWell(
          onTap: () => _showLangDialog(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('settings.language'), style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
              Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _darkModeItem(BuildContext context) {
    final themeStore = context.watch<ThemeStore>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr('settings.dark_mode'), style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
            Switch(
              value: themeStore.isDark,
              onChanged: (_) => themeStore.toggle(),
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr('settings.pin_code'), style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
            Switch(
              value: _pinEnabled,
              onChanged: (v) async {
                final prefs = await SharedPreferences.getInstance();
                if (!context.mounted) return;
                if (v) {
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PinScreen()));
                } else {
                  await prefs.remove('easyfinance_pin');
                }
                if (mounted) setState(() => _pinEnabled = v);
              },
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kopeksItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr('settings.show_kopeks'), style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
            Switch(
              value: _kopeksEnabled,
              onChanged: (v) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('easyfinance_show_kopeks', v);
                showKopeks = v;
                if (mounted) setState(() => _kopeksEnabled = v);
              },
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kopeksInOpsItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr('settings.show_kopeks_ops'), style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
            Switch(
              value: _kopeksInOpsEnabled,
              onChanged: (v) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('easyfinance_show_kopeks_ops', v);
                showKopeksInOps = v;
                if (mounted) setState(() => _kopeksInOpsEnabled = v);
              },
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _startScreenItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: InkWell(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final current = prefs.getString('easyfinance_start_screen') ?? 'main';
            if (!context.mounted) return;
            final result = await showDialog<String>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: Text(context.tr('settings.start_screen')),
                children: [
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, 'main'),
                    child: Row(children: [
                      Icon(Icons.home, size: 20, color: current == 'main' ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(context.tr('settings.start_home')),
                    ]),
                  ),
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, 'addOperation'),
                    child: Row(children: [
                      Icon(Icons.add_circle_outline, size: 20, color: current == 'addOperation' ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(context.tr('settings.start_operation')),
                    ]),
                  ),
                ],
              ),
            );
            if (result != null) await prefs.setString('easyfinance_start_screen', result);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('settings.start_screen'), style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, color: AppColors.textSecondaryFor(context)),
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
            ...['ru', 'en', 'es', 'it', 'fr', 'de', 'pt', 'tr'].map((code) => ListTile(
              title: Text(context.tr('settings.language_$code')),
              leading: Icon(Icons.check_circle, color: current == code ? AppColors.primary : Colors.transparent),
              onTap: () {
                final locale = Locale(code);
                context.read<LocaleStore>().setLocale(locale);
                context.setLocale(locale);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1));

  Widget _profileSection(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final user = store.currentUser;
    final name = user?.name ?? context.tr('profile.demo_user');
    final email = user?.email ?? 'demo@easyfinance.ru';
    final regDate = user?.registeredAt != null ? formatDateLong(user!.registeredAt!.toIso8601String()) : '—';
    final plan = user?.isPremium == true ? context.tr('profile.premium') : context.tr('profile.free');
    final syncLabel = user != null ? 'EasyFinance.ru' : context.tr('profile.local_data');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('profile.title'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
        const SizedBox(height: 8),
        _infoItem(context.tr('profile.name'), name),
        _infoItem('Email', email),
        _infoItem(context.tr('profile.tariff'), plan),
        _infoItem(context.tr('profile.reg_date'), regDate),
        _infoItem(context.tr('profile.sync'), syncLabel),
      ],
    );
  }

  Widget _supportItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen())),
          child: Row(
            children: [
              Icon(Icons.support_agent, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(context.tr('settings.support'), style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDateRange: DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
            );
            if (picked != null && context.mounted) {
              final store = context.read<FinanceStore>();
              try {
                await CsvExportService.export(store, picked.start, picked.end);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red));
                }
              }
            }
          },
          child: Row(
            children: [
              Icon(Icons.file_download_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(context.tr('settings.export_csv'), style: TextStyle(fontSize: 16, color: AppColors.textFor(context))),
            ],
          ),
        ),
      ),
    );
  }
}
