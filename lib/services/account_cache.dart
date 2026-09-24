import 'package:shared_preferences/shared_preferences.dart';

/// Namespaces per-account cache keys by the active user id, so each account's
/// local cache is kept separately and loaded when that account signs in.
class AccountCache {
  static const activeUidKey = 'easyfinance_active_uid';
  static String? _activeUid;

  static Future<String?> activeUid() async {
    final cached = _activeUid;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    _activeUid = prefs.getString(activeUidKey);
    return _activeUid;
  }

  static String? activeUidSync() => _activeUid;

  static Future<void> setActiveUid(String? uid) async {
    _activeUid = (uid == null || uid.isEmpty) ? null : uid;
    final prefs = await SharedPreferences.getInstance();
    if (uid == null || uid.isEmpty) {
      await prefs.remove(activeUidKey);
    } else {
      await prefs.setString(activeUidKey, uid);
    }
  }

  /// Returns the namespaced key for [base]: `base` for anonymous accounts,
  /// `base_<uid>` when a user id is known.
  static String key(String base, String? uid) =>
      (uid == null || uid.isEmpty) ? base : '${base}_$uid';

  static const _cacheKeyBases = <String>[
    'easyfinance_cached_accounts',
    'easyfinance_cached_categories',
    'easyfinance_cached_tags',
    'easyfinance_cached_user',
    'easyfinance_deleted_tags',
    'easyfinance_tachometers',
    'easyfinance_cached_tachometers',
    'display_currency',
    'easyfinance_budgets',
    'easyfinance_goals',
    'easyfinance_templates',
    'easyfinance_deleted_templates',
    'watched_currencies',
    'easyfinance_recommendation_prefs',
    'easyfinance_planned_payments',
  ];

  /// Удаляет локальный кеш конкретного аккаунта [uid] (для удалённых аккаунтов).
  static Future<void> clearAccount(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    for (final b in _cacheKeyBases) {
      await prefs.remove('${b}_$uid');
    }
  }

  /// Удаляет анонимный (безаккаунтный) кеш — используется при входе в
  /// демо-режим, чтобы не подтягивать данные предыдущего аккаунта.
  static Future<void> clearAnonymous() async {
    final prefs = await SharedPreferences.getInstance();
    for (final b in _cacheKeyBases) {
      await prefs.remove(b);
    }
  }
}