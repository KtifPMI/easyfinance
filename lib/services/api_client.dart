import 'dart:async';
import 'dart:convert';
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

  ApiClient({
    required this.appId,
    required this.secretKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

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
    params['sig'] = _buildSig(params, uidOverride: '');
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);

    try {
      final request = http.Request('GET', uri);
      final response = await _httpClient.send(request).timeout(_timeout);

      final finalUri = response.request?.url;
      if (finalUri != null) {
        final token = _extractTokenFromUri(finalUri);
        if (token != null) return token;
      }

      final body = await response.stream.bytesToString();
      final statusCode = response.statusCode;
      final location = finalUri?.toString();

      return _extractTokenFromBody(body, statusCode: statusCode, location: location);
    } on TimeoutException {
      throw ApiException('Token exchange timeout', 'TIMEOUT');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Token exchange failed: $e', 'EXCHANGE_FAIL');
    }
  }

  String? _extractTokenFromUri(Uri uri) {
    var token = uri.queryParameters['access_token'];
    if (token != null && token.isNotEmpty) return token;

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
      final resp = json['response'] as Map<String, dynamic>?;

      if (resp != null && resp.containsKey('response_error')) {
        final err = resp['response_error'] as Map<String, dynamic>;
        throw ApiException(err['error_message']?.toString() ?? 'Unknown error', err['error_code']?.toString() ?? 'API_ERROR');
      }

      final data = resp?['response_data'] as Map<String, dynamic>?;

      if (data != null && data.containsKey('access_token')) {
        final token = data['access_token']?.toString();
        if (token != null && token.isNotEmpty) return token;
      }

      if (resp != null && resp.containsKey('access_token')) {
        final token = resp['access_token']?.toString();
        if (token != null && token.isNotEmpty) return token;
      }

      if (json.containsKey('access_token')) {
        final token = json['access_token']?.toString();
        if (token != null && token.isNotEmpty) return token;
      }
    } on FormatException {
    } on ApiException {
      rethrow;
    }

    final patterns = [
      RegExp(r'"access_token"\s*:\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'access_token=([a-f0-9]+)', caseSensitive: false),
      RegExp(r'access_token[=:]\s*([a-f0-9]{16,})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final token = match.group(1);
        if (token != null && token.isNotEmpty) return token;
      }
    }

    final snippet = body.length > 500 ? '${body.substring(0, 500)}...' : body;
    final locInfo = location != null ? ' (redirect to: $location)' : '';
    throw ApiException('Token not found in response HTTP $statusCode$locInfo: $snippet', 'TOKEN_NOT_FOUND');
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
    if (response.statusCode != 200) {
      throw ApiException('HTTP ${response.statusCode}: ${response.body}', response.statusCode.toString());
    }
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response format: ${decoded.runtimeType}', 'INVALID_FORMAT');
    }
    final resp = decoded['response'] as Map<String, dynamic>?;
    if (resp != null && resp.containsKey('response_error')) {
      final err = resp['response_error'] as Map<String, dynamic>;
      throw ApiException(err['error_message']?.toString() ?? 'Unknown API error', err['error_code']?.toString() ?? 'API_ERROR');
    }
    if (resp != null && resp.containsKey('response_data')) {
      final data = resp['response_data'];
      if (data is Map<String, dynamic>) return data;
      return {'data': data};
    }
    return resp ?? decoded;
  }
}

class ApiException implements Exception {
  final String message;
  final String code;

  ApiException(this.message, this.code);

  @override
  String toString() => 'ApiException($code): $message';
}
