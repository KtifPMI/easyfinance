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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context.tr('rec_settings.food')),
          _slider('rec_settings.food_high', _prefs.foodHighPct, 10, 80, (v) { setState(() { _prefs.foodHighPct = v; }); _save(); }),
          _slider('rec_settings.food_medium', _prefs.foodMediumPct, 10, 60, (v) { setState(() { _prefs.foodMediumPct = v; }); _save(); }),
          _slider('rec_settings.dining_freq', _prefs.diningFrequency.toDouble(), 2, 20, (v) { setState(() { _prefs.diningFrequency = v.round(); }); _save(); }, divisions: 18, suffix: context.tr('rec_settings.times')),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.budgets')),
          _slider('rec_settings.budget_near', _prefs.budgetNearPct, 50, 95, (v) { setState(() { _prefs.budgetNearPct = v; }); _save(); }),
          _slider('rec_settings.no_budget_min', _prefs.noBudgetMinSpend.toDouble(), 100, 10000, (v) { setState(() { _prefs.noBudgetMinSpend = v.round(); }); _save(); }, divisions: 99, suffix: '₽'),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.savings')),
          _slider('rec_settings.savings_low', _prefs.savingsLowPct, 0, 30, (v) { setState(() { _prefs.savingsLowPct = v; }); _save(); }),
          _slider('rec_settings.savings_good', _prefs.savingsGoodPct, 10, 50, (v) { setState(() { _prefs.savingsGoodPct = v; }); _save(); }),
          _slider('rec_settings.housing', _prefs.housingPct, 10, 60, (v) { setState(() { _prefs.housingPct = v; }); _save(); }),
          _slider('rec_settings.emergency', _prefs.emergencyMonths, 1, 12, (v) { setState(() { _prefs.emergencyMonths = v; }); _save(); }, divisions: 11, suffix: context.tr('rec_settings.months')),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.cash')),
          _slider('rec_settings.idle_cash', _prefs.idleCashMin, 10000, 200000, (v) { setState(() { _prefs.idleCashMin = v; }); _save(); }, divisions: 19, suffix: '₽'),
          _slider('rec_settings.large_cash', _prefs.largeCashMin, 5000, 100000, (v) { setState(() { _prefs.largeCashMin = v; }); _save(); }, divisions: 19, suffix: '₽'),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.trends')),
          _slider('rec_settings.trend_up', _prefs.trendUpPct, 5, 50, (v) { setState(() { _prefs.trendUpPct = v; }); _save(); }),
          _slider('rec_settings.spike', _prefs.spikePct, 20, 200, (v) { setState(() { _prefs.spikePct = v; }); _save(); }),
          _slider('rec_settings.recurring', _prefs.recurringMonths.toDouble(), 2, 12, (v) { setState(() { _prefs.recurringMonths = v.round(); }); _save(); }, divisions: 10, suffix: context.tr('rec_settings.months')),
          _slider('rec_settings.single_cat', _prefs.singleCatDominancePct, 20, 80, (v) { setState(() { _prefs.singleCatDominancePct = v; }); _save(); }),
          _slider('rec_settings.weekend', _prefs.weekendRatioPct, 30, 90, (v) { setState(() { _prefs.weekendRatioPct = v; }); _save(); }),
          _slider('rec_settings.top_cat', _prefs.topCatMinPct, 5, 40, (v) { setState(() { _prefs.topCatMinPct = v; }); _save(); }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged, {int? divisions, String? suffix}) {
    final displayVal = value == value.roundToDouble() && value < 1000 ? value.round().toString() : value.toStringAsFixed(value < 100 ? 1 : 0);
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
                Expanded(child: Text(context.tr(label), style: TextStyle(fontSize: 14, color: AppColors.textFor(context)))),
                Text('$displayVal${suffix != null ? ' $suffix' : '%'}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
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
