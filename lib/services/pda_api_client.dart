import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class PdaApiClient {
  static const String baseUrl = 'https://easyfinance.ru/pda/';
  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _httpClient;
  String? _authToken;

  PdaApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  String? get authToken => _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void clearAuth() {
    _authToken = null;
  }

  Future<void> authenticate(String login, String password) async {
    final resp = await _httpClient
        .post(Uri.parse('${baseUrl}authenticate'), body: {
          'login': login,
          'password': password,
        })
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      throw ApiException('PDA auth failed: HTTP ${resp.statusCode}', resp.statusCode.toString());
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;

    final errors = json['errors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final first = errors.first as Map<String, dynamic>;
      throw ApiException(
        first['text']?.toString() ?? 'PDA auth error',
        first['code']?.toString() ?? 'PDA_AUTH_ERROR',
      );
    }

    final data = json['data'] as Map<String, dynamic>?;
    final token = data?['auth_token']?.toString() ?? json['auth_token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('PDA auth failed: no auth_token', 'NO_TOKEN');
    }
    _authToken = token;
  }

  Future<Map<String, dynamic>> post(String endpoint, {Map<String, String>? params}) async {
    final body = <String, String>{
      if (_authToken != null) 'auth_token': _authToken!,
      ...?params,
    };

    final response = await _httpClient
        .post(Uri.parse('${baseUrl}$endpoint'), body: body)
        .timeout(_timeout);

    return _handleResponse(response, endpoint);
  }

  Map<String, dynamic> _handleResponse(http.Response response, String endpoint) {
    if (response.statusCode != 200) {
      throw ApiException('PDA HTTP ${response.statusCode} for $endpoint: ${response.body}', response.statusCode.toString());
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final errors = json['errors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final first = errors.first as Map<String, dynamic>;
      throw ApiException(
        first['text']?.toString() ?? 'PDA error for $endpoint',
        first['code']?.toString() ?? 'PDA_ERROR',
      );
    }

    return json['data'] as Map<String, dynamic>? ?? json;
  }

  void dispose() {
    _httpClient.close();
  }
}
