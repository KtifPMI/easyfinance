import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import 'api_service.dart';

class AuthService {
  final ApiClient _apiClient;

  // Encrypted storage (Android Keystore / iOS Keychain).
  // Holds only the session secrets; appId/secretKey come from AppConfig at runtime.
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  static const String _tokenKey = 'easyfinance_access_token';
  static const String _userIdKey = 'easyfinance_user_id';
  static const String _webSessionKey = 'easyfinance_web_session';
  // Legacy plaintext SharedPreferences keys (one-time migration only).
  static const String _legacyAppIdKey = 'easyfinance_app_id';
  static const String _legacySecretKeyKey = 'easyfinance_secret_key';

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
    String? token = await _secure.read(key: _tokenKey);
    String? userId = await _secure.read(key: _userIdKey);
    String? webSession = await _secure.read(key: _webSessionKey);

    if (token == null) {
      // One-time migration from plaintext SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_tokenKey);
      userId = prefs.getString(_userIdKey);
      webSession = prefs.getString(_webSessionKey);
      if (token != null) {
        await _secure.write(key: _tokenKey, value: token);
        if (userId != null) await _secure.write(key: _userIdKey, value: userId);
        if (webSession != null) await _secure.write(key: _webSessionKey, value: webSession);
        await prefs.remove(_tokenKey);
        await prefs.remove(_userIdKey);
        await prefs.remove(_webSessionKey);
        await prefs.remove(_legacyAppIdKey);
        await prefs.remove(_legacySecretKeyKey);
      }
    }

    if (token != null && token.isNotEmpty) {
      _apiClient.setAuth(accessToken: token, userId: userId);
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

    await _secure.write(key: _tokenKey, value: accessToken);
    if (userId != null) await _secure.write(key: _userIdKey, value: userId);
    if (webSession != null && webSession.isNotEmpty) {
      await _secure.write(key: _webSessionKey, value: webSession);
    } else {
      await _secure.delete(key: _webSessionKey);
    }
    await migrateLegacyPin();
  }

  Future<void> logout() async {
    _apiClient.clearAuth();
    _apiService = null;
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _userIdKey);
    await _secure.delete(key: _webSessionKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_webSessionKey);
    await prefs.remove(_legacyAppIdKey);
    await prefs.remove(_legacySecretKeyKey);
  }
}
