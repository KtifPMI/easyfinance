import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'https://api.easyfinance.ru/v2/';

  final String appId;
  final String secretKey;
  String? _accessToken;
  String? _userId;

  ApiClient({required this.appId, required this.secretKey});

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

  String _md5(String input) => md5.convert(utf8.encode(input)).toString();

  String _buildSig(Map<String, String> params, {String? uidOverride}) {
    final sorted = Map.fromEntries(params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
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
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    return uri;
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

    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final streamedResponse = await client.send(request);

      final finalUri = streamedResponse.request?.url;
      final token = finalUri?.queryParameters['access_token'];
      if (token != null && token.isNotEmpty) return token;

      final body = await streamedResponse.stream.bytesToString();

      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final resp = json['response'] as Map<String, dynamic>?;
        final data = resp?['response_data'] as Map<String, dynamic>?;
        if (data?.containsKey('access_token') == true) {
          return data!['access_token'].toString();
        }
        if (resp?.containsKey('response_error') == true) {
          final err = resp!['response_error'] as Map<String, dynamic>;
          throw ApiException(err['error_message']?.toString() ?? 'Unknown error', err['error_code']?.toString() ?? '');
        }
      } catch (_) {}

      if (body.contains('access_token')) {
        final rx = RegExp(r'access_token[=:]\s*["\']?([a-f0-9]+)');
        final m = rx.firstMatch(body);
        if (m != null) return m.group(1)!;
      }

      throw ApiException('Token exchange failed: no access_token in response', 'EXCHANGE_FAIL');
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> get(String method, {Map<String, String>? params}) async {
    final uri = _buildUri(method, params ?? {});
    final response = await http.get(uri);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String method, {Map<String, String>? params, Map<String, dynamic>? body}) async {
    final uri = _buildUri(method, params ?? {});
    final response = await http.post(uri, body: body != null ? jsonEncode(body) : null, headers: {'Content-Type': 'application/json'});
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final resp = decoded['response'] as Map<String, dynamic>?;
      if (resp != null && resp.containsKey('response_error')) {
        final err = resp['response_error'] as Map<String, dynamic>;
        throw ApiException(err['error_message']?.toString() ?? 'Unknown API error', err['error_code']?.toString() ?? '');
      }
      return decoded;
    }
    throw ApiException('HTTP ${response.statusCode}: ${response.body}', response.statusCode.toString());
  }
}

class ApiException implements Exception {
  final String message;
  final String code;
  ApiException(this.message, this.code);
  @override
  String toString() => 'ApiException($code): $message';
}
