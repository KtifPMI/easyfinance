import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'api_service.dart';

class AuthService {
  final ApiClient _apiClient;
  static const String _tokenKey = 'easyfinance_access_token';
  static const String _userIdKey = 'easyfinance_user_id';
  static const String _appIdKey = 'easyfinance_app_id';
  static const String _secretKeyKey = 'easyfinance_secret_key';
  static const String _webSessionKey = 'easyfinance_web_session';

  AuthService(this._apiClient);

  ApiClient get apiClient => _apiClient;
  ApiService? _apiService;
  ApiService get apiService => _apiService ?? ApiService(_apiClient);

  String? get userId => _apiClient.userId;

  bool get isAuthenticated => _apiClient.accessToken != null;

  // --- PIN code (per-account, hashed) ---
  static const String _legacyPinKey = 'easyfinance_pin';

  String get _pinKey {
    final uid = userId;
    return (uid != null && uid.isNotEmpty) ? 'easyfinance_pin_$uid' : _legacyPinKey;
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt::$pin');
    return sha256.convert(bytes).toString();
  }

  String _newSalt() {
    final rnd = Random.secure();
    return List<int>.generate(16, (_) => rnd.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_pinKey);
    return v != null && v.isNotEmpty;
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey);
    if (stored == null || stored.isEmpty) return false;
    if (!stored.contains(':')) return stored == pin; // legacy plaintext fallback
    final parts = stored.split(':');
    final salt = parts[0];
    final hash = parts[1];
    return _hashPin(pin, salt) == hash;
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = _newSalt();
    await prefs.setString(_pinKey, '$salt:${_hashPin(pin, salt)}');
  }

  Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
  }

  /// Moves the legacy global (plaintext) PIN into the current account's key, hashed (one-time).
  Future<void> migrateLegacyPin() async {
    final uid = userId;
    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPinKey);
    if (legacy == null || legacy.isEmpty) return;
    final key = 'easyfinance_pin_$uid';
    if (prefs.getString(key) == null) {
      final salt = _newSalt();
      await prefs.setString(key, '$salt:${_hashPin(legacy, salt)}');
    }
    await prefs.remove(_legacyPinKey);
  }

  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    final appId = prefs.getString(_appIdKey);
    final secretKey = prefs.getString(_secretKeyKey);

    if (token != null && appId != null && secretKey != null) {
      _apiClient.setAuth(accessToken: token, userId: userId);
      final webSession = prefs.getString(_webSessionKey);
      if (webSession != null && webSession.isNotEmpty) {
        _apiClient.setWebSession(webSession);
      }
      _apiService = ApiService(_apiClient);
      await migrateLegacyPin();
      return true;
    }
    return false;
  }

  Future<void> saveCredentials({
    required String appId,
    required String secretKey,
    required String accessToken,
    String? userId,
    String? webSession,
  }) async {
    _apiClient.setAuth(accessToken: accessToken, userId: userId);
    if (webSession != null && webSession.isNotEmpty) {
      _apiClient.setWebSession(webSession);
    }
    _apiService = ApiService(_apiClient);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    if (userId != null) await prefs.setString(_userIdKey, userId);
    await prefs.setString(_appIdKey, appId);
    await prefs.setString(_secretKeyKey, secretKey);
    if (webSession != null && webSession.isNotEmpty) {
      await prefs.setString(_webSessionKey, webSession);
    }
    await migrateLegacyPin();
  }

  Future<void> logout() async {
    _apiClient.clearAuth();
    _apiService = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_appIdKey);
    await prefs.remove(_secretKeyKey);
    await prefs.remove(_webSessionKey);
  }
}
