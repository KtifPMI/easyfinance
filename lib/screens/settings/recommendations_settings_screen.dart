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
                Text(context.tr('settings.recommendations'), style: Theme.of(context).textTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                const SizedBox(height: 4),
                Text(
                  'Эти настройки управляют советами в разделе «Рекомендации». Каждый ползунок задаёт порог, при котором появляется соответствующий совет. Чем ниже порог — тем чаще появляются советы.',
                  style: Theme.of(context).textTheme.bodySmall.copyWith(color: AppColors.textSecondaryFor(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionHeader(context.tr('rec_settings.food')),
          _slider('rec_settings.food_high', _prefs.foodHighPct, 10, 80, (v) { setState(() { _prefs.foodHighPct = v; }); _save(); }, hint: 'Доля расходов на продукты и кафе в доходе выше этого порога — совет сократить траты на еду.'),
          _slider('rec_settings.food_medium', _prefs.foodMediumPct, 10, 60, (v) { setState(() { _prefs.foodMediumPct = v; }); _save(); }, hint: 'Более мягкий порог доли расходов на еду в доходе для менее строгого совета.'),
          _slider('rec_settings.dining_freq', _prefs.diningFrequency.toDouble(), 2, 20, (v) { setState(() { _prefs.diningFrequency = v.round(); }); _save(); }, divisions: 18, suffix: context.tr('rec_settings.times'), hint: 'Число походов в кафе или рестораны за месяц, начиная с которого появляется совет об общепите.'),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.budgets')),
          _slider('rec_settings.budget_near', _prefs.budgetNearPct, 50, 95, (v) { setState(() { _prefs.budgetNearPct = v; }); _save(); }, hint: 'Если по бюджету потрачено больше этого процента от лимита — совет, что лимит скоро закончится.'),
          _slider('rec_settings.no_budget_min', _prefs.noBudgetMinSpend.toDouble(), 100, 10000, (v) { setState(() { _prefs.noBudgetMinSpend = v.round(); }); _save(); }, divisions: 99, suffix: '₽', hint: 'Категории без бюджета, по которым потрачено больше этой суммы — предлагаем завести бюджет.'),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.savings')),
          _slider('rec_settings.savings_low', _prefs.savingsLowPct, 0, 30, (v) { setState(() { _prefs.savingsLowPct = v; }); _save(); }, hint: 'Если доля сбережений в доходе ниже порога — совет начать откладывать.'),
          _slider('rec_settings.savings_good', _prefs.savingsGoodPct, 10, 50, (v) { setState(() { _prefs.savingsGoodPct = v; }); _save(); }, hint: 'Целевая доля сбережений в доходе, при достижении которой даём поздравление.'),
          _slider('rec_settings.housing', _prefs.housingPct, 10, 60, (v) { setState(() { _prefs.housingPct = v; }); _save(); }, hint: 'Доля расходов на жильё в доходе выше порога — совет пересмотреть траты.'),
          _slider('rec_settings.emergency', _prefs.emergencyMonths, 1, 12, (v) { setState(() { _prefs.emergencyMonths = v; }); _save(); }, divisions: 11, suffix: context.tr('rec_settings.months'), hint: 'Рекомендуемый размер резервного фонда в месяцах расходов.'),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.cash')),
          _slider('rec_settings.idle_cash', _prefs.idleCashMin, 10000, 200000, (v) { setState(() { _prefs.idleCashMin = v; }); _save(); }, divisions: 19, suffix: '₽', hint: 'Свободные наличные и остатки на счетах больше этой суммы — совет вложить, чтобы деньги не лежали мёртвым грузом.'),
          _slider('rec_settings.large_cash', _prefs.largeCashMin, 5000, 100000, (v) { setState(() { _prefs.largeCashMin = v; }); _save(); }, divisions: 19, suffix: '₽', hint: 'Отдельная трата больше этой суммы — совет проверить крупную покупку.'),
          const SizedBox(height: 16),
          _sectionHeader(context.tr('rec_settings.trends')),
          _slider('rec_settings.trend_up', _prefs.trendUpPct, 5, 50, (v) { setState(() { _prefs.trendUpPct = v; }); _save(); }, hint: 'Рост расходов по сравнению с прошлым месяцем больше порога — совет про тренд вверх.'),
          _slider('rec_settings.spike', _prefs.spikePct, 20, 200, (v) { setState(() { _prefs.spikePct = v; }); _save(); }, hint: 'Всплеск по категории выше среднего на этот процент — совет о разовом скачке.'),
          _slider('rec_settings.recurring', _prefs.recurringMonths.toDouble(), 2, 12, (v) { setState(() { _prefs.recurringMonths = v.round(); }); _save(); }, divisions: 10, suffix: context.tr('rec_settings.months'), hint: 'Число месяцев подряд с одним и тем же магазином или платежом — помечаем как регулярный платёж.'),
          _slider('rec_settings.single_cat', _prefs.singleCatDominancePct, 20, 80, (v) { setState(() { _prefs.singleCatDominancePct = v; }); _save(); }, hint: 'Если одна категория занимает больше этого процента всех расходов — совет о сильной зависимости.'),
          _slider('rec_settings.weekend', _prefs.weekendRatioPct, 30, 90, (v) { setState(() { _prefs.weekendRatioPct = v; }); _save(); }, hint: 'Доля трат в выходные выше порога — совет обратить внимание на weekend-траты.'),
          _slider('rec_settings.top_cat', _prefs.topCatMinPct, 5, 40, (v) { setState(() { _prefs.topCatMinPct = v; }); _save(); }, hint: 'Категория, превышающая этот процент расходов — попадает в топ-категории.'),
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
    final displayVal = suffix == '₽'
        ? '${_formatRub(value)} ₽'
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
                Expanded(child: Text(context.tr(label), style: Theme.of(context).textTheme.bodyMedium.copyWith(color: AppColors.textFor(context)))),
                Text(displayVal, style: Theme.of(context).textTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(hint, style: Theme.of(context).textTheme.labelSmall.copyWith(color: AppColors.textSecondaryFor(context))),
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
