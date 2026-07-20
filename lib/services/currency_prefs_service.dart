import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyPrefsService {
  static const _key = 'watched_currencies';

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final list = jsonDecode(data) as List<dynamic>;
    return list.cast<String>();
  }

  static Future<void> save(List<String> codes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(codes));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
