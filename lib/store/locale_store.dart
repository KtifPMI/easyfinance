import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleStore extends ChangeNotifier {
  static const _key = 'easyfinance_locale';

  static const List<String> supportedCodes = ['ru', 'en', 'es', 'it', 'fr', 'de', 'pt', 'tr'];

  static List<Locale> get supportedLocales =>
      supportedCodes.map((code) => Locale(code)).toList();

  Locale _locale = const Locale('ru');

  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      _locale = Locale(saved);
    } else {
      _locale = _localeFromDevice();
    }
    notifyListeners();
  }

  /// Resolves the startup locale from the device language when the user has
  /// not picked a language manually. Unsupported device languages fall back
  /// to English. Not persisted, so the app keeps following the device
  /// language until the user explicitly chooses one in settings.
  Locale _localeFromDevice() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return supportedCodes.contains(code) ? Locale(code) : const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
    notifyListeners();
  }
}