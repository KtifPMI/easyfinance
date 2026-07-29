import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RateHistoryStorage {
  static const _prefix = 'rate_';

  static String _key(DateTime date) => '$_prefix${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime? _dateFromKey(String key) {
    if (!key.startsWith(_prefix)) return null;
    return DateTime.tryParse(key.substring(_prefix.length));
  }

  static Future<void> saveRates(DateTime date, Map<String, double> rates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(date), jsonEncode(rates));
    _cleanOld(prefs);
  }

  static Future<Map<String, double>?> getRates(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(date));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
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

  static Future<void> _cleanOld(SharedPreferences prefs) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      final d = _dateFromKey(key);
      if (d != null && d.isBefore(cutoff)) {
        await prefs.remove(key);
      }
    }
  }
}
