import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'api_service.dart';

class AuthService {
  final ApiClient _apiClient;
  static const String _tokenKey = 'easyfinance_access_token';
  static const String _userIdKey = 'easyfinance_user_id';
  static const String _appIdKey = 'easyfinance_app_id';
  static const String _secretKeyKey = 'easyfinance_secret_key';

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
  }) async {
    _apiClient.setAuth(accessToken: accessToken, userId: userId);
    _apiService = ApiService(_apiClient);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    if (userId != null) await prefs.setString(_userIdKey, userId);
    await prefs.setString(_appIdKey, appId);
    await prefs.setString(_secretKeyKey, secretKey);
  }

  Future<void> logout() async {
    _apiClient.clearAuth();
    _apiService = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_appIdKey);
    await prefs.remove(_secretKeyKey);
  }
}
