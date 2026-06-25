import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'https://api.easyfinance.ru/v2/';
  static const Duration _timeout = Duration(seconds: 30);

  final String appId;
  final String secretKey;
  String? _accessToken;
  String? _userId;

  final http.Client _httpClient;
  final HttpClient _dartHttpClient;

  ApiClient({
    required this.appId,
    required this.secretKey,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _dartHttpClient = HttpClient()..autoUncompress = true;

  String? get accessToken => _accessToken;
  String? get userId => _userId;

  void setAuth({required String accessToken, String? userId}) {
    _accessToken = accessToken;
    _userId = userId;
  }

  void clearAuth() {
    _accessToken = null;
    _userId = null;
  }

  void dispose() {
    _httpClient.close();
    _dartHttpClient.close();
  }

  String _md5(String input) => md5.convert(utf8.encode(input)).toString();

  String _buildSig(Map<String, String> params, {String? uidOverride}) {
    final sorted = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final paramStr = sorted.entries.map((e) => '${e.key}=${e.value}').join('&');
    final uid = uidOverride ?? _userId ?? '';
    return _md5('$secretKey$uid$paramStr');
  }

  Uri _buildUri(String method, Map<String, String> extraParams) {
    final params = <String, String>{
      'method': method,
      'app_id': appId,
      if (_accessToken != null) 'access_token': _accessToken!,
      ...extraParams,
    };
    params['sig'] = _buildSig(params);
    return Uri.parse(baseUrl).replace(queryParameters: params);
  }

  Uri buildOAuthCodeUrl() {
    final params = <String, String>{
      'app_id': appId,
      'response_type': 'code',
    };
    params['sig'] = _buildSig(params);
    return Uri.parse(baseUrl).replace(queryParameters: params);
  }

  Future<String> exchangeCodeForToken(String code) async {
    final params = <String, String>{
      'app_id': appId,
      'code': code,
      'grant_type': 'authorization_code',
      'response_type': 'token',
    };
    params['sig'] = _buildSig(params);
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);

    try {
      final request = await _dartHttpClient
          .getUrl(uri)
          .timeout(_timeout, onTimeout: (_) => throw ApiException('Request timeout', 'TIMEOUT'));
      final response = await request.close();
      final statusCode = response.statusCode;
      final location = response.headers.value('location');

      // Проверяем токен в Location header (query или fragment)
      if (location != null) {
        final locUri = Uri.parse(location);
        final token = _extractTokenFromUri(locUri);
        if (token != null) return token;
      }

      // Если нет редиректа или токен не найден в URL, читаем body
      final body = await response.transform(utf8.decoder).join();
      return _extractTokenFromBody(body, statusCode: statusCode, location: location);
    } on TimeoutException {
      throw ApiException('Token exchange timeout', 'TIMEOUT');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Token exchange failed: $e', 'EXCHANGE_FAIL');
    }
  }

  String? _extractTokenFromUri(Uri uri) {
    // Проверяем query parameters
    var token = uri.queryParameters['access_token'];
    if (token != null && token.isNotEmpty) return token;

    // Проверяем fragment (стандарт OAuth 2.0)
    if (uri.hasFragment) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      token = fragmentParams['access_token'];
      if (token != null && token.isNotEmpty) return token;
    }

    return null;
  }

  String _extractTokenFromBody(String body, {int? statusCode, String? location}) {
    // Пытаемся распарсить JSON
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final resp = json['response'] as Map<String, dynamic>?;

      // Ищем токен в response_data
      final data = resp?['response_data'] as Map<String, dynamic>?;
      if (data?.containsKey('access_token') == true) {
        final token = data!['access_token']?.toString();
        if (token != null && token.isNotEmpty) return token;
      }

      // Проверяем наличие ошибки
      if (resp?.containsKey('response_error') == true) {
        final err = resp!['response_error'] as Map<String, dynamic>;
        throw ApiException(
          err['error_message']?.toString() ?? 'Unknown error',
          err['error_code']?.toString() ?? 'API_ERROR',
        );
      }
    } on FormatException {
      // Не JSON, продолжаем поиск в тексте
    } on ApiException {
      rethrow;
    }

    // Ищем токен в тексте через regex
    final rx = RegExp(r'access_token[=:]\s*([a-f0-9]+)', caseSensitive: false);
    final match = rx.firstMatch(body);
    if (match != null) return match.group(1)!;

    // Токен не найден
    final snippet = body.length > 300 ? '${body.substring(0, 300)}...' : body;
    final locInfo = location != null ? ' (redirect to: $location)' : '';
    throw ApiException(
      'Token exchange failed HTTP $statusCode$locInfo: $snippet',
      'EXCHANGE_FAIL',
    );
  }

  Future<Map<String, dynamic>> get(String method, {Map<String, String>? params}) async {
    final uri = _buildUri(method, params ?? {});
    final response = await _httpClient
        .get(uri)
        .timeout(_timeout, onTimeout: () => throw ApiException('Request timeout', 'TIMEOUT'));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String method, {
    Map<String, String>? params,
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(method, params ?? {});
    final response = await _httpClient
        .post(
          uri,
          body: body != null ? jsonEncode(body) : null,
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(_timeout, onTimeout: () => throw ApiException('Request timeout', 'TIMEOUT'));
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final resp = decoded['response'] as Map<String, dynamic>?;

        // Проверяем наличие ошибки в ответе
        if (resp != null && resp.containsKey('response_error')) {
          final err = resp['response_error'] as Map<String, dynamic>;
          throw ApiException(
            err['error_message']?.toString() ?? 'Unknown API error',
            err['error_code']?.toString() ?? 'API_ERROR',
          );
        }

        // Возвращаем response_data если есть, иначе весь response, иначе весь ответ
        if (resp?.containsKey('response_data') == true) {
          return resp!['response_data'] as Map<String, dynamic>;
        }
        return resp ?? decoded;
      } on FormatException {
        throw ApiException(
          'Invalid JSON response: ${response.body.substring(0, response.body.length.clamp(0, 200))}',
          'INVALID_JSON',
        );
      }
    }

    throw ApiException(
      'HTTP ${response.statusCode}: ${response.body}',
      response.statusCode.toString(),
    );
  }
}

class ApiException implements Exception {
  final String message;
  final String code;

  ApiException(this.message, this.code);

  @override
  String toString() => 'ApiException($code): $message';
}
