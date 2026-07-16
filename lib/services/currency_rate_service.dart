import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyRateService {
  static const _cbrUrl = 'https://www.cbr.ru/scripts/XML_daily.asp';
  static const _cacheKey = 'currency_rates';
  static const _cacheDateKey = 'currency_rates_date';

  static Future<Map<String, double>> fetchRates() async {
    final cached = await _loadCached();
    if (cached != null) return cached;

    try {
      final today = DateTime.now();
      final dateStr =
          '${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}';
      final uri = Uri.parse('$_cbrUrl?date_req=$dateStr');
      final response = await http
          .get(uri, headers: {'User-Agent': 'EasyFinance/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return await _loadCache() ?? {};

      final rates = _parseXml(response.body);
      if (rates.isNotEmpty) await _saveCache(rates);
      return rates;
    } catch (_) {
      final cached = await _loadCache();
      return cached ?? {};
    }
  }

  static Map<String, double> _parseXml(String xml) {
    final rates = <String, double>{};
    final valuteRegex = RegExp(
      r'<Valute[^>]*>.*?<CharCode>(\w+)</CharCode>.*?<Nominal>(\d+)</Nominal>.*?<Value>([\d,]+)</Value>.*?</Valute>',
      dotAll: true,
    );

    for (final m in valuteRegex.allMatches(xml)) {
      final code = m.group(1) ?? '';
      final nominal = int.tryParse(m.group(2) ?? '1') ?? 1;
      final valueStr = (m.group(3) ?? '0').replaceAll(',', '.');
      final value = double.tryParse(valueStr) ?? 0.0;
      if (code.isNotEmpty && value > 0) {
        rates[code] = value / nominal;
      }
    }
    return rates;
  }

  static double convert(
      double amount, String from, String to, Map<String, double> rates) {
    if (from == to) return amount;
    final rub = amount * (from == 'RUB' ? 1.0 : (rates[from] ?? 0.0));
    if (to == 'RUB') return rub;
    final toRate = rates[to] ?? 0.0;
    return toRate > 0 ? rub / toRate : 0.0;
  }

  static Future<Map<String, double>?> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_cacheDateKey);
    if (dateStr == null) return null;
    final today = DateTime.now();
    final cachedDate = DateTime.tryParse(dateStr);
    if (cachedDate != null &&
        cachedDate.year == today.year &&
        cachedDate.month == today.month &&
        cachedDate.day == today.day) {
      return _loadCache();
    }
    return null;
  }

  static Future<Map<String, double>?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCache(Map<String, double> rates) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    await prefs.setString(_cacheKey, jsonEncode(rates));
    await prefs.setString(
        _cacheDateKey,
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');
  }
}
