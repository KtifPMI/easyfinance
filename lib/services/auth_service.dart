import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'api_service.dart';
import 'pda_api_client.dart';
import 'pda_api_service.dart';

class AuthService {
  final ApiClient _apiClient;
  final PdaApiClient _pdaClient;
  static const String _tokenKey = 'easyfinance_access_token';
  static const String _userIdKey = 'easyfinance_user_id';
  static const String _appIdKey = 'easyfinance_app_id';
  static const String _secretKeyKey = 'easyfinance_secret_key';
  static const String _pdaTokenKey = 'easyfinance_pda_token';

  AuthService(this._apiClient) : _pdaClient = PdaApiClient();

  ApiClient get apiClient => _apiClient;
  PdaApiClient get pdaClient => _pdaClient;
  ApiService? _apiService;
  ApiService get apiService => _apiService ?? ApiService(_apiClient);
  PdaApiService? _pdaService;
  PdaApiService get pdaService => _pdaService ?? PdaApiService(_pdaClient);

  String? get userId => _apiClient.userId;

  bool get isAuthenticated => _apiClient.accessToken != null;

  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    final appId = prefs.getString(_appIdKey);
    final secretKey = prefs.getString(_secretKeyKey);
    final pdaToken = prefs.getString(_pdaTokenKey);

    if (token != null && appId != null && secretKey != null) {
      _apiClient.setAuth(accessToken: token, userId: userId);
      _apiService = ApiService(_apiClient);
      if (pdaToken != null) _pdaClient.setAuthToken(pdaToken);
      _pdaService = PdaApiService(_pdaClient);
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
    _pdaService = PdaApiService(_pdaClient);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    if (userId != null) await prefs.setString(_userIdKey, userId);
    await prefs.setString(_appIdKey, appId);
    await prefs.setString(_secretKeyKey, secretKey);
  }

  Future<void> savePdaToken(String token) async {
    _pdaClient.setAuthToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pdaTokenKey, token);
  }

  Future<void> logout() async {
    _apiClient.clearAuth();
    _pdaClient.clearAuth();
    _apiService = null;
    _pdaService = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_appIdKey);
    await prefs.remove(_secretKeyKey);
    await prefs.remove(_pdaTokenKey);
  }
}
