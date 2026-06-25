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

  String _buildSig(Map<String, String> params) {
    final sorted = Map.fromEntries(params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    final paramStr = sorted.entries.map((e) => '${e.key}=${e.value}').join('&');
    final uid = _userId ?? '';
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
        throw ApiException(err['error_message']?.toString() ?? 'Unknown API error', err['error_code']?.toString());
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
