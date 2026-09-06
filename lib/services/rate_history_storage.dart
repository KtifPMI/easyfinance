import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RateHistoryStorage {
  static const _collectionKey = 'easyfinance_rate_history';

  static Future<void> saveRates(DateTime date, Map<String, double> rates) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_collectionKey);
    final Map<String, dynamic> all = raw != null ? jsonDecode(raw) as Map<String, dynamic> : {};
    final key = _dateKey(date);
    all[key] = rates;
    _cleanOld(all);
    await prefs.setString(_collectionKey, jsonEncode(all));
  }

  static Future<Map<String, double>?> getRates(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_collectionKey);
    if (raw == null) return null;
    try {
      final all = jsonDecode(raw) as Map<String, dynamic>;
      final entry = all[_dateKey(date)];
      if (entry == null) return null;
      return (entry as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, double>> getClosestRates(DateTime date, Map<String, double> fallback) async {
    final exact = await getRates(date);
    if (exact != null) return exact;

    for (int offset = 1; offset <= 30; offset++) {
      final prev = await getRates(date.subtract(Duration(days: offset)));
      if (prev != null) return prev;
    }
    return fallback;
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static void _cleanOld(Map<String, dynamic> all) {
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final cutoffStr = _dateKey(cutoff);
    final keysToRemove = <String>[];
    for (final key in all.keys) {
      if (key.compareTo(cutoffStr) < 0) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      all.remove(key);
    }
  }
}
