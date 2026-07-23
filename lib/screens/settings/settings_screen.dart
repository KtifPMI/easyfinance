import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../services/currency_rate_service.dart';
import '../../services/update_service.dart';
import '../../store/finance_store.dart';
import '../../store/locale_store.dart';
import '../../store/planned_payment_store.dart';
import '../../store/theme_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../../utils/currency_utils.dart';
import '../auth/pin_screen.dart';
import 'recommendations_settings_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadPinStatus();
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

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: context.tr('settings.title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileSection(context),
          const SizedBox(height: 8),
          Text(context.tr('settings.app_section'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          _langItem(context),
          _darkModeItem(context),
          _currenciesItem(context),
          _pinItem(context),
          _recommendationsItem(context),
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
                    Text(context.tr('settings.check_updates'), style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
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
                    Text(context.tr('settings.logout'), style: TextStyle(fontSize: 15, color: AppColors.expense)),
                  ],
                ),
              ),
            ),
          ),
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
            Text(title, style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
            Text(value, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
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
              Text(context.tr('settings.language'), style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
              Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
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
            Text(context.tr('settings.dark_mode'), style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
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

  Widget _currenciesItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const _CurrencyManageScreen()));
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('settings.currencies'), style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
              Icon(Icons.chevron_right, color: AppColors.textSecondaryFor(context)),
            ],
          ),
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
            Text(context.tr('settings.pin_code'), style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
            Switch(
              value: _pinEnabled,
              onChanged: (v) async {
                final prefs = await SharedPreferences.getInstance();
                if (!mounted) return;
                if (v) {
                  if (!mounted) return;
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

  Widget _recommendationsItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const RecommendationsSettingsScreen()));
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('settings.recommendations'), style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
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
        Text(context.tr('profile.title'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
        const SizedBox(height: 8),
        _infoItem(context.tr('profile.name'), name),
        _infoItem('Email', email),
        _infoItem(context.tr('profile.tariff'), plan),
        _infoItem(context.tr('profile.reg_date'), regDate),
        _infoItem(context.tr('profile.sync'), syncLabel),
      ],
    );
  }
}

class _CurrencyManageScreen extends StatefulWidget {
  const _CurrencyManageScreen();
  @override
  State<_CurrencyManageScreen> createState() => _CurrencyManageScreenState();
}

class _CurrencyManageScreenState extends State<_CurrencyManageScreen> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    final store = context.read<FinanceStore>();
    _selected = List<String>.from(store.watchedCurrencies.where((c) => c != 'RUB'));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final allCodes = allCurrencyCodes.where((c) => c != 'RUB').toList();
    return ScreenScaffold(
      title: context.tr('settings.currencies'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(context.tr('settings.select_currencies_hint'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          ),
          ...allCodes.map((code) => CheckboxListTile(
            value: _selected.contains(code),
            title: Row(
              children: [
                Text(currencySymbol(code), style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(code, style: TextStyle(fontSize: 15)),
              ],
            ),
            subtitle: Text(CurrencyRateService.convert(1, 'RUB', code, store.rates) > 0
                ? '1 RUB = ${CurrencyRateService.convert(1, 'RUB', code, store.rates).toStringAsFixed(4)} ${currencySymbol(code)}'
                : context.tr('settings.no_data'),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selected.add(code);
                } else {
                  _selected.remove(code);
                }
              });
            },
            activeColor: AppColors.primary,
            controlAffinity: ListTileControlAffinity.trailing,
          )),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  store.setWatchedCurrencies(['RUB', ..._selected]);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.tr('budget.save'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
