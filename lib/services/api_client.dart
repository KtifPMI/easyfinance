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
        _dartHttpClient = HttpClient()
          ..autoUncompress = true
          ..autoRedirect = false; // 🔥 КРИТИЧНО: отключаем авто-редирект

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
    // 🔥 Явно указываем пустой uid, т.к. при обмене кода пользователь ещё не авторизован
    params['sig'] = _buildSig(params, uidOverride: '');
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);

    try {
      print('=== Token Exchange Request ===');
      print('URL: $uri');

      final request = await _dartHttpClient.getUrl(uri).timeout(_timeout);
      request.followRedirects = false; // 🔥 Для ясности
      
      final response = await request.close().timeout(_timeout);
      final statusCode = response.statusCode;
      final location = response.headers.value('location');

      print('=== Token Exchange Response ===');
      print('Status: $statusCode');
      print('Location: $location');

      // Если есть редирект (302/301/307/308), ищем токен в Location
      if (location != null && (statusCode == 301 || statusCode == 302 || statusCode == 307 || statusCode == 308)) {
        print('Redirect detected: $location');
        final locUri = Uri.parse(location);
        final token = _extractTokenFromUri(locUri);
        if (token != null) {
          print('✅ Token found in redirect location');
          return token;
        }
      }

      // Иначе читаем body (для 200 OK или если в Location нет токена)
      final body = await response.transform(utf8.decoder).join();
      print('Body length: ${body.length}');
      print('Body preview: ${body.length > 500 ? '${body.substring(0, 500)}...' : body}');

      return _extractTokenFromBody(body, statusCode: statusCode, location: location);
    } on TimeoutException {
      throw ApiException('Token exchange timeout', 'TIMEOUT');
    } on ApiException {
      rethrow;
    } catch (e, stackTrace) {
      print('Token exchange error: $e');
      print('Stack trace: $stackTrace');
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
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      print('JSON parsed successfully');

      final resp = json['response'] as Map<String, dynamic>?;
      
      // Проверяем наличие ошибки
      if (resp?.containsKey('response_error') == true) {
        final err = resp!['response_error'] as Map<String, dynamic>;
        throw ApiException(
          err['error_message']?.toString() ?? 'Unknown error',
          err['error_code']?.toString() ?? 'API_ERROR',
        );
      }

      final data = resp?['response_data'] as Map<String, dynamic>?;

      // Ищем токен в разных местах
      if (data?.containsKey('access_token') == true) {
        final token = data!['access_token']?.toString();
        if (token != null && token.isNotEmpty) {
          print('✅ Token found in response_data.access_token');
          return token;
        }
      }

      if (resp?.containsKey('access_token') == true) {
        final token = resp!['access_token']?.toString();
        if (token != null && token.isNotEmpty) {
          print('✅ Token found in response.access_token');
          return token;
        }
      }

      if (json.containsKey('access_token')) {
        final token = json['access_token']?.toString();
        if (token != null && token.isNotEmpty) {
          print('✅ Token found in root access_token');
          return token;
        }
      }

      print('Token not found in JSON structure');
    } on FormatException {
      print('Response is not JSON');
    } on ApiException {
      rethrow;
    }

    // Ищем токен через regex
    final patterns = [
      RegExp(r'"access_token"\s*:\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'access_token=([a-f0-9]+)', caseSensitive: false),
      RegExp(r'access_token[=:]\s*["\']?([a-f0-9]{16,})["\']?', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final token = match.group(1);
        if (token != null && token.isNotEmpty) {
          print('✅ Token found via regex: $token');
          return token;
        }
      }
    }

    final snippet = body.length > 500 ? '${body.substring(0, 500)}...' : body;
    final locInfo = location != null ? ' (redirect to: $location)' : '';
    throw ApiException(
      'Token not found in response HTTP $statusCode$locInfo: $snippet',
      'TOKEN_NOT_FOUND',
    );
  }

  Future<Map<String, dynamic>> get(String method, {Map<String, String>? params}) async {
    final uri = _buildUri(method, params ?? {});
    final response = await _httpClient.get(uri).timeout(_timeout);
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
        .timeout(_timeout);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      try {
        final dynamic decoded = jsonDecode(response.body);
        
        // 🔥 Проверяем тип ответа
        if (decoded is! Map<String, dynamic>) {
          throw ApiException(
            'Unexpected response format: ${decoded.runtimeType}',
            'INVALID_FORMAT',
          );
        }

        final resp = decoded['response'] as Map<String, dynamic>?;

        if (resp != null && resp.containsKey('response_error')) {
          final err = resp['response_error'] as Map<String, dynamic>;
          throw ApiException(
            err['error_message']?.toString() ?? 'Unknown API error',
            err['error_code']?.toString() ?? 'API_ERROR',
          );
        }

        if (resp?.containsKey('response_data') == true) {
          final data = resp!['response_data'];
          if (data is Map<String, dynamic>) {
            return data;
          }
          // Если response_data не Map, возвращаем как есть
          return {'data': data};
        }
        
        return resp ?? decoded;
      } on FormatException {
        final snippet = response.body.length > 200 
            ? response.body.substring(0, 200) 
            : response.body;
        throw ApiException(
          'Invalid JSON response: $snippet',
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
