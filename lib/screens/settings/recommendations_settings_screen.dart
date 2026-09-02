import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/recommendation_prefs.dart';
import '../../theme/theme.dart';

class RecommendationsSettingsScreen extends StatefulWidget {
  const RecommendationsSettingsScreen({super.key});
  @override
  State<RecommendationsSettingsScreen> createState() => _RecommendationsSettingsScreenState();
}

class _RecommendationsSettingsScreenState extends State<RecommendationsSettingsScreen> {
  late RecommendationPrefs _prefs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await RecommendationPrefs.load();
    if (!mounted) return;
    setState(() { _prefs = prefs; _loading = false; });
  }

  Future<void> _save() async {
    await _prefs.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return ScreenScaffold(
      title: context.tr('settings.recommendations'),
      showLogo: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('settings.recommendations'), style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                const SizedBox(height: 4),
                Text(
                  'Р­С‚Рё РЅР°СЃС‚СЂРѕР№РєРё СѓРїСЂР°РІР»СЏСЋС‚ СЃРѕРІРµС‚Р°РјРё РІ СЂР°Р·РґРµР»Рµ В«Р РµРєРѕРјРµРЅРґР°С†РёРёВ». РљР°Р¶РґС‹Р№ РїРѕР»Р·СѓРЅРѕРє Р·Р°РґР°С‘С‚ РїРѕСЂРѕРі, РїСЂРё РєРѕС‚РѕСЂРѕРј РїРѕСЏРІР»СЏРµС‚СЃСЏ СЃРѕРѕС‚РІРµС‚СЃС‚РІСѓСЋС‰РёР№ СЃРѕРІРµС‚. Р§РµРј РЅРёР¶Рµ РїРѕСЂРѕРі вЂ” С‚РµРј С‡Р°С‰Рµ РїРѕСЏРІР»СЏСЋС‚СЃСЏ СЃРѕРІРµС‚С‹.',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.textSecondaryFor(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionHeader(context.tr('rec_settings.food')),
          _slider('rec_settings.food_high', _prefs.foodHighPct, 10, 80, (v) { setState(() { _prefs.foodHighPct = v; }); _save(); }, hint: 'Р”РѕР»СЏ СЂР°СЃС…РѕРґРѕРІ РЅР° РїСЂРѕРґСѓРєС‚С‹ Рё РєР°С„Рµ РІ РґРѕС…РѕРґРµ РІС‹С€Рµ СЌС‚РѕРіРѕ РїРѕСЂРѕРіР° вЂ” СЃРѕРІРµС‚ СЃРѕРєСЂР°С‚РёС‚СЊ С‚СЂР°С‚С‹ РЅР° РµРґСѓ.'),
          _slider('rec_settings.food_medium', _prefs.foodMediumPct, 10, 60, (v) { setState(() { _prefs.foodMediumPct = v; }); _save(); }, hint: 'Р‘РѕР»РµРµ РјСЏРіРєРёР№ РїРѕСЂРѕРі РґРѕР»Рё СЂР°СЃС…РѕРґРѕРІ РЅР° РµРґСѓ РІ РґРѕС…РѕРґРµ РґР»СЏ РјРµРЅРµРµ СЃС‚СЂРѕРіРѕРіРѕ СЃРѕРІРµС‚Р°.'),
          _slider('rec_settings.dining_freq', _prefs.diningFrequency.toDouble(), 2, 20, (v) { setState(() { _prefs.diningFrequency = v.round(); }); _save(); }, divisions: 18, suffix: context.tr('rec_settings.times'), hint: 'Р§РёСЃР»Рѕ РїРѕС…РѕРґРѕРІ РІ РєР°С„Рµ РёР»Рё СЂРµСЃС‚РѕСЂР°РЅС‹ Р·Р° РјРµСЃСЏС†, РЅР°С‡РёРЅР°СЏ СЃ РєРѕС‚РѕСЂРѕРіРѕ РїРѕСЏРІР»СЏРµС‚СЃСЏ СЃРѕРІРµС‚ РѕР± РѕР±С‰РµРїРёС‚Рµ.'),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.budgets')),
          _slider('rec_settings.budget_near', _prefs.budgetNearPct, 50, 95, (v) { setState(() { _prefs.budgetNearPct = v; }); _save(); }, hint: 'Р•СЃР»Рё РїРѕ Р±СЋРґР¶РµС‚Сѓ РїРѕС‚СЂР°С‡РµРЅРѕ Р±РѕР»СЊС€Рµ СЌС‚РѕРіРѕ РїСЂРѕС†РµРЅС‚Р° РѕС‚ Р»РёРјРёС‚Р° вЂ” СЃРѕРІРµС‚, С‡С‚Рѕ Р»РёРјРёС‚ СЃРєРѕСЂРѕ Р·Р°РєРѕРЅС‡РёС‚СЃСЏ.'),
          _slider('rec_settings.no_budget_min', _prefs.noBudgetMinSpend.toDouble(), 100, 10000, (v) { setState(() { _prefs.noBudgetMinSpend = v.round(); }); _save(); }, divisions: 99, suffix: '?', hint: 'РљР°С‚РµРіРѕСЂРёРё Р±РµР· Р±СЋРґР¶РµС‚Р°, РїРѕ РєРѕС‚РѕСЂС‹Рј РїРѕС‚СЂР°С‡РµРЅРѕ Р±РѕР»СЊС€Рµ СЌС‚РѕР№ СЃСѓРјРјС‹ вЂ” РїСЂРµРґР»Р°РіР°РµРј Р·Р°РІРµСЃС‚Рё Р±СЋРґР¶РµС‚.'),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.savings')),
          _slider('rec_settings.savings_low', _prefs.savingsLowPct, 0, 30, (v) { setState(() { _prefs.savingsLowPct = v; }); _save(); }, hint: 'Р•СЃР»Рё РґРѕР»СЏ СЃР±РµСЂРµР¶РµРЅРёР№ РІ РґРѕС…РѕРґРµ РЅРёР¶Рµ РїРѕСЂРѕРіР° вЂ” СЃРѕРІРµС‚ РЅР°С‡Р°С‚СЊ РѕС‚РєР»Р°РґС‹РІР°С‚СЊ.'),
          _slider('rec_settings.savings_good', _prefs.savingsGoodPct, 10, 50, (v) { setState(() { _prefs.savingsGoodPct = v; }); _save(); }, hint: 'Р¦РµР»РµРІР°СЏ РґРѕР»СЏ СЃР±РµСЂРµР¶РµРЅРёР№ РІ РґРѕС…РѕРґРµ, РїСЂРё РґРѕСЃС‚РёР¶РµРЅРёРё РєРѕС‚РѕСЂРѕР№ РґР°С‘Рј РїРѕР·РґСЂР°РІР»РµРЅРёРµ.'),
          _slider('rec_settings.housing', _prefs.housingPct, 10, 60, (v) { setState(() { _prefs.housingPct = v; }); _save(); }, hint: 'Р”РѕР»СЏ СЂР°СЃС…РѕРґРѕРІ РЅР° Р¶РёР»СЊС‘ РІ РґРѕС…РѕРґРµ РІС‹С€Рµ РїРѕСЂРѕРіР° вЂ” СЃРѕРІРµС‚ РїРµСЂРµСЃРјРѕС‚СЂРµС‚СЊ С‚СЂР°С‚С‹.'),
          _slider('rec_settings.emergency', _prefs.emergencyMonths, 1, 12, (v) { setState(() { _prefs.emergencyMonths = v; }); _save(); }, divisions: 11, suffix: context.tr('rec_settings.months'), hint: 'Р РµРєРѕРјРµРЅРґСѓРµРјС‹Р№ СЂР°Р·РјРµСЂ СЂРµР·РµСЂРІРЅРѕРіРѕ С„РѕРЅРґР° РІ РјРµСЃСЏС†Р°С… СЂР°СЃС…РѕРґРѕРІ.'),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.cash')),
          _slider('rec_settings.idle_cash', _prefs.idleCashMin, 10000, 200000, (v) { setState(() { _prefs.idleCashMin = v; }); _save(); }, divisions: 19, suffix: '?', hint: 'РЎРІРѕР±РѕРґРЅС‹Рµ РЅР°Р»РёС‡РЅС‹Рµ Рё РѕСЃС‚Р°С‚РєРё РЅР° СЃС‡РµС‚Р°С… Р±РѕР»СЊС€Рµ СЌС‚РѕР№ СЃСѓРјРјС‹ вЂ” СЃРѕРІРµС‚ РІР»РѕР¶РёС‚СЊ, С‡С‚РѕР±С‹ РґРµРЅСЊРіРё РЅРµ Р»РµР¶Р°Р»Рё РјС‘СЂС‚РІС‹Рј РіСЂСѓР·РѕРј.'),
          _slider('rec_settings.large_cash', _prefs.largeCashMin, 5000, 100000, (v) { setState(() { _prefs.largeCashMin = v; }); _save(); }, divisions: 19, suffix: '?', hint: 'РћС‚РґРµР»СЊРЅР°СЏ С‚СЂР°С‚Р° Р±РѕР»СЊС€Рµ СЌС‚РѕР№ СЃСѓРјРјС‹ вЂ” СЃРѕРІРµС‚ РїСЂРѕРІРµСЂРёС‚СЊ РєСЂСѓРїРЅСѓСЋ РїРѕРєСѓРїРєСѓ.'),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.trends')),
          _slider('rec_settings.trend_up', _prefs.trendUpPct, 5, 50, (v) { setState(() { _prefs.trendUpPct = v; }); _save(); }, hint: 'Р РѕСЃС‚ СЂР°СЃС…РѕРґРѕРІ РїРѕ СЃСЂР°РІРЅРµРЅРёСЋ СЃ РїСЂРѕС€Р»С‹Рј РјРµСЃСЏС†РµРј Р±РѕР»СЊС€Рµ РїРѕСЂРѕРіР° вЂ” СЃРѕРІРµС‚ РїСЂРѕ С‚СЂРµРЅРґ РІРІРµСЂС….'),
          _slider('rec_settings.spike', _prefs.spikePct, 20, 200, (v) { setState(() { _prefs.spikePct = v; }); _save(); }, hint: 'Р’СЃРїР»РµСЃРє РїРѕ РєР°С‚РµРіРѕСЂРёРё РІС‹С€Рµ СЃСЂРµРґРЅРµРіРѕ РЅР° СЌС‚РѕС‚ РїСЂРѕС†РµРЅС‚ вЂ” СЃРѕРІРµС‚ Рѕ СЂР°Р·РѕРІРѕРј СЃРєР°С‡РєРµ.'),
          _slider('rec_settings.recurring', _prefs.recurringMonths.toDouble(), 2, 12, (v) { setState(() { _prefs.recurringMonths = v.round(); }); _save(); }, divisions: 10, suffix: context.tr('rec_settings.months'), hint: 'Р§РёСЃР»Рѕ РјРµСЃСЏС†РµРІ РїРѕРґСЂСЏРґ СЃ РѕРґРЅРёРј Рё С‚РµРј Р¶Рµ РјР°РіР°Р·РёРЅРѕРј РёР»Рё РїР»Р°С‚РµР¶РѕРј вЂ” РїРѕРјРµС‡Р°РµРј РєР°Рє СЂРµРіСѓР»СЏСЂРЅС‹Р№ РїР»Р°С‚С‘Р¶.'),
          _slider('rec_settings.single_cat', _prefs.singleCatDominancePct, 20, 80, (v) { setState(() { _prefs.singleCatDominancePct = v; }); _save(); }, hint: 'Р•СЃР»Рё РѕРґРЅР° РєР°С‚РµРіРѕСЂРёСЏ Р·Р°РЅРёРјР°РµС‚ Р±РѕР»СЊС€Рµ СЌС‚РѕРіРѕ РїСЂРѕС†РµРЅС‚Р° РІСЃРµС… СЂР°СЃС…РѕРґРѕРІ вЂ” СЃРѕРІРµС‚ Рѕ СЃРёР»СЊРЅРѕР№ Р·Р°РІРёСЃРёРјРѕСЃС‚Рё.'),
          _slider('rec_settings.weekend', _prefs.weekendRatioPct, 30, 90, (v) { setState(() { _prefs.weekendRatioPct = v; }); _save(); }, hint: 'Р”РѕР»СЏ С‚СЂР°С‚ РІ РІС‹С…РѕРґРЅС‹Рµ РІС‹С€Рµ РїРѕСЂРѕРіР° вЂ” СЃРѕРІРµС‚ РѕР±СЂР°С‚РёС‚СЊ РІРЅРёРјР°РЅРёРµ РЅР° weekend-С‚СЂР°С‚С‹.'),
          _slider('rec_settings.top_cat', _prefs.topCatMinPct, 5, 40, (v) { setState(() { _prefs.topCatMinPct = v; }); _save(); }, hint: 'РљР°С‚РµРіРѕСЂРёСЏ, РїСЂРµРІС‹С€Р°СЋС‰Р°СЏ СЌС‚РѕС‚ РїСЂРѕС†РµРЅС‚ СЂР°СЃС…РѕРґРѕРІ вЂ” РїРѕРїР°РґР°РµС‚ РІ С‚РѕРї-РєР°С‚РµРіРѕСЂРёРё.'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
    );
  }

  String _formatRub(double value) {
    final s = value.round().toString();
    return s.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged, {int? divisions, String? suffix, String? hint}) {
    final displayVal = suffix == '?'
        ? '${_formatRub(value)} ?'
        : '${value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(value < 100 ? 1 : 0)}${suffix != null ? ' $suffix' : '%'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(context.tr(label), style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: AppColors.textFor(context)))),
                Text(displayVal, style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(hint, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: AppColors.textSecondaryFor(context))),
              ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions ?? (max - min).round().clamp(1, 100),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
