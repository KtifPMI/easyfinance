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
