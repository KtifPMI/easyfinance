import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HomeModule { finHealth, rates, recommendations, upcoming, budgets, goals, reports }

class HomeModulesPrefs extends ChangeNotifier {
  static const _key = 'easyfinance_home_hidden_modules';

  final Set<HomeModule> _hidden = {};

  HomeModulesPrefs() {
    _load();
  }

  bool isVisible(HomeModule module) => !_hidden.contains(module);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? const [];
    _hidden
      ..clear()
      ..addAll(HomeModule.values.where((m) => saved.contains(m.name)));
    notifyListeners();
  }

  Future<void> setVisible(HomeModule module, bool visible) async {
    if (visible) {
      _hidden.remove(module);
    } else {
      _hidden.add(module);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _hidden.map((m) => m.name).toList());
  }
}
