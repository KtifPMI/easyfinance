import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleStore extends ChangeNotifier {
  static const _key = 'easyfinance_locale';
  Locale _locale = const Locale('ru');

  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'ru';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
    notifyListeners();
  }
}
