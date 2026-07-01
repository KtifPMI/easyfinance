import 'package:shared_preferences/shared_preferences.dart';

class HintService {
  static const _key = 'easyfinance_seen_hints';

  static Future<bool> isHintSeen(String hintId) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_key) ?? [];
    return seen.contains(hintId);
  }

  static Future<void> markSeen(String hintId) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_key) ?? [];
    if (!seen.contains(hintId)) {
      seen.add(hintId);
      await prefs.setStringList(_key, seen);
    }
  }
}
