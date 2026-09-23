import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_cache.dart';

class CurrencyPrefsService {
  static const _key = 'watched_currencies';

  static String _k(String? uid) => AccountCache.key(_key, uid);

  static Future<List<String>> load({String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_k(uid));
    if (data == null) return [];
    final list = jsonDecode(data) as List<dynamic>;
    return list.cast<String>();
  }

  static Future<void> save(List<String> codes, {String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_k(uid), jsonEncode(codes));
  }

  static Future<void> clear({String? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k(uid));
  }
}