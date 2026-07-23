import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecommendationPrefs {
  static const _key = 'easyfinance_recommendation_prefs';

  double foodHighPct;
  double foodMediumPct;
  int diningFrequency;
  double housingPct;
  double savingsLowPct;
  double savingsGoodPct;
  double emergencyMonths;
  double idleCashMin;
  int noBudgetMinSpend;
  int budgetNearPct;
  double topCatMinPct;

  // --- New types ---
  double trendUpPct;
  double spikePct;
  int recurringMonths;
  double singleCatDominancePct;
  int weekendRatioPct;
  double largeCashMin;

  RecommendationPrefs({
    this.foodHighPct = 50,
    this.foodMediumPct = 30,
    this.diningFrequency = 5,
    this.housingPct = 30,
    this.savingsLowPct = 10,
    this.savingsGoodPct = 20,
    this.emergencyMonths = 3,
    this.idleCashMin = 50000,
    this.noBudgetMinSpend = 1000,
    this.budgetNearPct = 80,
    this.topCatMinPct = 15,
    this.trendUpPct = 20,
    this.spikePct = 50,
    this.recurringMonths = 3,
    this.singleCatDominancePct = 40,
    this.weekendRatioPct = 60,
    this.largeCashMin = 30000,
  });

  Map<String, dynamic> toJson() => {
    'foodHighPct': foodHighPct,
    'foodMediumPct': foodMediumPct,
    'diningFrequency': diningFrequency,
    'housingPct': housingPct,
    'savingsLowPct': savingsLowPct,
    'savingsGoodPct': savingsGoodPct,
    'emergencyMonths': emergencyMonths,
    'idleCashMin': idleCashMin,
    'noBudgetMinSpend': noBudgetMinSpend,
    'budgetNearPct': budgetNearPct,
    'topCatMinPct': topCatMinPct,
    'trendUpPct': trendUpPct,
    'spikePct': spikePct,
    'recurringMonths': recurringMonths,
    'singleCatDominancePct': singleCatDominancePct,
    'weekendRatioPct': weekendRatioPct,
    'largeCashMin': largeCashMin,
  };

  factory RecommendationPrefs.fromJson(Map<String, dynamic> j) => RecommendationPrefs(
    foodHighPct: (j['foodHighPct'] ?? 50).toDouble(),
    foodMediumPct: (j['foodMediumPct'] ?? 30).toDouble(),
    diningFrequency: j['diningFrequency'] ?? 5,
    housingPct: (j['housingPct'] ?? 30).toDouble(),
    savingsLowPct: (j['savingsLowPct'] ?? 10).toDouble(),
    savingsGoodPct: (j['savingsGoodPct'] ?? 20).toDouble(),
    emergencyMonths: (j['emergencyMonths'] ?? 3).toDouble(),
    idleCashMin: (j['idleCashMin'] ?? 50000).toDouble(),
    noBudgetMinSpend: j['noBudgetMinSpend'] ?? 1000,
    budgetNearPct: (j['budgetNearPct'] ?? 80).toDouble(),
    topCatMinPct: (j['topCatMinPct'] ?? 15).toDouble(),
    trendUpPct: (j['trendUpPct'] ?? 20).toDouble(),
    spikePct: (j['spikePct'] ?? 50).toDouble(),
    recurringMonths: j['recurringMonths'] ?? 3,
    singleCatDominancePct: (j['singleCatDominancePct'] ?? 40).toDouble(),
    weekendRatioPct: (j['weekendRatioPct'] ?? 60).toDouble(),
    largeCashMin: (j['largeCashMin'] ?? 30000).toDouble(),
  );

  static Future<RecommendationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        return RecommendationPrefs.fromJson(jsonDecode(raw));
      } catch (_) {}
    }
    return RecommendationPrefs();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }

  RecommendationPrefs copy() => RecommendationPrefs.fromJson(toJson());
}
