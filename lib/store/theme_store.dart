import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeStore extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('easyfinance_dark_mode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggle() async {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('easyfinance_dark_mode', isDark);
  }

  Future<void> setDark(bool value) async {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('easyfinance_dark_mode', value);
  }
}
