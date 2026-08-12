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

  /// Invoked when the server reports that the access token is invalid/expired.
  /// Lets the UI show a "session expired" banner and offer to sign in again.
  void Function()? onAuthExpired;

  ApiClient({
    required this.appId,
    required this.secretKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  bool _isAuthExpiredError(ApiException e) {
    final code = e.code;
    if (code == '68' || code == '5') return true;
    final msg = e.message.toLowerCase();
    return msg.contains('access token') || msg.contains('authorization failed');
  }

  void _notifyAuthExpired(ApiException e) {
    if (_isAuthExpiredError(e)) onAuthExpired?.call();
  }

  String? get accessToken => _accessToken;
  String? get userId => _userId;

  String? _webSessionId;

  String? get webSessionId => _webSessionId;

  void setWebSession(String? id) {
    _webSessionId = id;
  }

  void setAuth({required String accessToken, String? userId}) {
    _accessToken = accessToken;
    _userId = userId;
  }

  void clearAuth() {
    _accessToken = null;
    _userId = null;
    _webSessionId = null;
  }

  void clearWebSession() {
    _webSessionId = null;
  }

  Future<void> loginWeb(String login, String password) async {
    final uri = Uri.parse('https://easyfinance.ru/login/');
    final resp = await _httpClient.post(uri, body: {'login': login, 'pass': password}).timeout(_timeout);
    final setCookie = resp.headers['set-cookie'];
    if (setCookie != null) {
      final match = RegExp(r'PHPSESSID=([^;]+)').firstMatch(setCookie);
      if (match != null) {
        _webSessionId = match.group(1);
        return;
      }
    }
    throw ApiException('Web login failed: no PHPSESSID cookie', 'WEB_LOGIN_FAIL');
  }

  void dispose() {
    _httpClient.close();
  }

  String _md5(String input) => md5.convert(utf8.encode(input)).toString();

  /// Рассчитать подпись для запроса (без uid, для регистрации)
  String calculateSig(String paramsStr) {
    return _md5('$secretKey$paramsStr');
  }

  String _buildSig(Map<String, String> params, {bool includeUid = false}) {
    final order = ['method', 'app_id', 'access_token'];
    final ordered = <String, String>{};
    for (final key in order) {
      if (params.containsKey(key)) ordered[key] = params[key]!;
    }
    for (final e in params.entries) {
      if (!ordered.containsKey(e.key)) ordered[e.key] = e.value;
    }
    final paramStr = ordered.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    
    if (includeUid && _userId != null && _userId!.isNotEmpty) {
      return _md5('$secretKey$_userId$paramStr');
    }
    return _md5('$secretKey$paramStr');
  }

  Uri _buildUri(String method, Map<String, String> extraParams) {
    final params = <String, String>{
      'method': method,
      'app_id': appId,
      if (_accessToken != null) 'access_token': _accessToken!,
      ...extraParams,
    };
    params['sig'] = _buildSig(params, includeUid: true);
    return Uri.parse(baseUrl).replace(queryParameters: params);
  }

  Uri buildPostUri(String method) {
    final params = <String, String>{
      'method': method,
      'app_id': appId,
      if (_accessToken != null) 'access_token': _accessToken!,
    };
    params['sig'] = _buildSig(params, includeUid: true);
    return Uri.parse(baseUrl).replace(queryParameters: params);
  }

  Uri buildOAuthCodeUrl() {
    final params = <String, String>{
      'app_id': appId,
      'response_type': 'code',
    };
    params['sig'] = _buildSig(params, includeUid: false);
    return Uri.parse(baseUrl).replace(queryParameters: params);
  }

  Future<String> exchangeCodeForToken(String code) async {
    final params = <String, String>{
      'app_id': appId,
      'code': code,
      'grant_type': 'authorization_code',
      'response_type': 'token',
    };
    
    // При обмене кода uid НЕ используется в подписи
    params['sig'] = _buildSig(params, includeUid: false);
    final uri = Uri.parse(baseUrl).replace(queryParameters: params);

    try {
      final client = HttpClient()..autoUncompress = true;

      try {
        final request = await client.getUrl(uri).timeout(_timeout);
        request.followRedirects = false;

        final response = await request.close().timeout(_timeout);
        final statusCode = response.statusCode;
        final location = response.headers.value('location');

        if (location != null && _isRedirect(statusCode)) {
          final locUri = Uri.parse(location);
          final token = _extractTokenFromUri(locUri);
          if (token != null) return token;
        }

        final body = await response.transform(utf8.decoder).join();

        return _extractTokenFromBody(body, statusCode: statusCode, location: location);
      } finally {
        client.close();
      }
    } on TimeoutException {
      throw ApiException('Token exchange timeout', 'TIMEOUT');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Token exchange failed: $e', 'EXCHANGE_FAIL');
    }
  }

  bool _isRedirect(int statusCode) {
    return statusCode == 301 || statusCode == 302 || statusCode == 307 || statusCode == 308;
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
      final resp = json['response'] as Map<String, dynamic>?;

      if (resp != null && resp.containsKey('response_error')) {
        final err = resp['response_error'] as Map<String, dynamic>;
        throw ApiException(
          err['error_message']?.toString() ?? 'Unknown error',
          err['error_code']?.toString() ?? 'API_ERROR',
        );
      }

      final data = resp?['response_data'] as Map<String, dynamic>?;

      if (data != null && data.containsKey('errors')) {
        final errors = data['errors'] as List<dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          final first = errors.first as Map<String, dynamic>;
          throw ApiException(
            first['text']?.toString() ?? 'API error',
            first['code']?.toString() ?? 'API_ERROR',
          );
        }
      }

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
      // not JSON
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
    throw ApiException(
      'Token not found in response HTTP $statusCode$locInfo: $snippet',
      'TOKEN_NOT_FOUND',
    );
  }

  Future<DebugResponse> getDirect(String url, {Map<String, String>? headers}) async {
    var finalUrl = url;
    final hdrs = <String, String>{
      'Accept': '*/*',
      'X-Requested-With': 'XMLHttpRequest',
      ...?headers,
    };

    if (_webSessionId != null) {
      hdrs['Cookie'] = 'PHPSESSID=$_webSessionId';
    } else if (_accessToken != null) {
      final parsed = Uri.parse(url);
      final params = Map<String, String>.from(parsed.queryParameters);
      params['access_token'] = _accessToken!;
      finalUrl = parsed.replace(queryParameters: params).toString();
    }

    final response = await _httpClient.get(Uri.parse(finalUrl), headers: hdrs).timeout(_timeout);
    return DebugResponse(
      statusCode: response.statusCode,
      body: response.body,
      url: finalUrl,
      headers: Map<String, String>.from(response.headers.map((k, v) => MapEntry(k.toLowerCase(), v))),
    );
  }

  Future<Map<String, dynamic>> get(String method, {Map<String, String>? params}) async {
    final uri = _buildUri(method, params ?? {});
    final response = await _httpClient.get(uri).timeout(_timeout);
    try {
      return _handleResponse(response);
    } on ApiException catch (e) {
      _notifyAuthExpired(e);
      rethrow;
    }
  }

  /// Sends a support/feedback message through the website form endpoint.
  Future<String> sendFeedback({required String title, required String message, required String email}) async {
    final uri = Uri.parse('https://easyfinance.ru/feedback/add_message/?responseMode=json');
    final body = <String, String>{
      'responseMode': 'json',
      'title': title,
      'msg': message,
      'email': email,
      'cheight': '0',
      'cwidth': '0',
      'width': '0',
      'height': '0',
      'colors': '32',
      'plugins': '',
    };
    final headers = <String, String>{
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'X-Requested-With': 'XMLHttpRequest',
      'Origin': 'https://easyfinance.ru',
      'Referer': 'https://easyfinance.ru/',
      if (_webSessionId != null) 'Cookie': 'PHPSESSID=$_webSessionId',
    };
    final response = await _httpClient.post(uri, body: body, headers: headers).timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException('HTTP ${response.statusCode}: ${response.body}', response.statusCode.toString());
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException('Unexpected response format', 'INVALID_FORMAT');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected response format', 'INVALID_FORMAT');
    }
    if (decoded.containsKey('error')) {
      throw ApiException(decoded['error'].toString(), 'FEEDBACK_ERROR');
    }
    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw ApiException(errors.first.toString(), 'FEEDBACK_ERROR');
    }
    final result = decoded['result'];
    if (result is Map<String, dynamic>) {
      final text = result['text']?.toString();
      if (text != null && text.isNotEmpty) return text;
    }
    return 'OK';
  }

  // --- Calendar / Planned Payments (website endpoint, requires PHPSESSID) ---

  /// Fetches planned/calendar events from the website.
  Future<Map<String, dynamic>> getCalendarEvents() async {
    final uri = Uri.parse('https://easyfinance.ru/calendar/events/?responseMode=json');
    final hdrs = <String, String>{
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (_webSessionId != null) 'Cookie': 'PHPSESSID=$_webSessionId',
    };
    final response = await _httpClient.get(uri, headers: hdrs).timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException('Calendar HTTP ${response.statusCode}', 'CALENDAR_ERROR');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['result'] is Map<String, dynamic>) return decoded['result'] as Map<String, dynamic>;
    return decoded;
  }

  /// Creates or updates a planned calendar event via the website form endpoint.
  /// [data] is the form-urlencoded body. Returns the server response.
  Future<Map<String, dynamic>> postCalendarEvent(Map<String, String> data) async {
    final uri = Uri.parse('https://easyfinance.ru/calendar/add/?responseMode=json');
    final hdrs = <String, String>{
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      'Origin': 'https://easyfinance.ru',
      'Referer': 'https://easyfinance.ru/calendar/',
      'Content-Type': 'application/x-www-form-urlencoded',
      if (_webSessionId != null) 'Cookie': 'PHPSESSID=$_webSessionId',
    };
    final response = await _httpClient.post(uri, headers: hdrs, body: data).timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException('Calendar HTTP ${response.statusCode}: ${response.body}', 'CALENDAR_POST_ERROR');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['result'] is Map<String, dynamic>) return decoded['result'] as Map<String, dynamic>;
    return decoded;
  }

  /// Deletes a calendar event by operation id.
  Future<void> deleteCalendarEvent(String operationId, String chainId) async {
    final uri = Uri.parse('https://easyfinance.ru/calendar/delete/?responseMode=json');
    final hdrs = <String, String>{
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      'Origin': 'https://easyfinance.ru',
      'Referer': 'https://easyfinance.ru/calendar/',
      'Content-Type': 'application/x-www-form-urlencoded',
      if (_webSessionId != null) 'Cookie': 'PHPSESSID=$_webSessionId',
    };
    final body = <String, String>{
      'responseMode': 'json',
      'id': operationId,
      'chain': chainId,
    };
    final response = await _httpClient.post(uri, headers: hdrs, body: body).timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException('Calendar delete HTTP ${response.statusCode}: ${response.body}', 'CALENDAR_DELETE_ERROR');
    }
  }

  // --- Calendar / Planned Payments (API v2) ---

  String _transactKey() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Fetches planned/calendar events from the API v2 (method `calendar.get`).
  Future<List<Map<String, dynamic>>> getCalendarEventsV2({String? from, String? to, bool accepted = false}) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (accepted) params['options'] = 'accepted';
    final data = await get('calendar.get', params: params);
    final list = data['calendar'] as List<dynamic>?;
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Creates a planned calendar event (operation + chain) via API v2 `calendar.post`.
  Future<Map<String, dynamic>> postCalendarEventV2(Map<String, dynamic> body) async {
    return post('calendar.post', params: {'transact_key': _transactKey()}, body: {'request': {'request_data': body}});
  }

  /// Updates a planned calendar event via API v2 `calendar.set`.
  Future<Map<String, dynamic>> setCalendarEventV2(String operationId, String chainId, Map<String, dynamic> body) async {
    return post('calendar.set', params: {'transact_key': _transactKey(), 'operation_id': operationId, 'chain_id': chainId}, body: {'request': {'request_data': body}});
  }

  /// Deletes a planned calendar event via API v2 `calendar.delete`.
  Future<Map<String, dynamic>> deleteCalendarEventV2(String operationId, String chainId) async {
    return post('calendar.delete', params: {'transact_key': _transactKey(), 'operation_id': operationId, 'chain_id': chainId}, body: {'request': {'request_data': {}}});
  }

  /// Confirms (accepts) a planned occurrence via API v2 `calendar.accept`.
  Future<Map<String, dynamic>> acceptCalendarEventV2(String operationId, String chainId, String date) async {
    return post('calendar.accept', params: {'transact_key': _transactKey(), 'operation_id': operationId, 'chain_id': chainId}, body: {'request': {'request_data': {'date': date, 'accepted': 1}}});
  }

  Future<DebugResponse> getRaw(String method, {Map<String, String>? params}) async {
    final uri = _buildUri(method, params ?? {});
    final response = await _httpClient.get(uri).timeout(_timeout);
    return DebugResponse(
      statusCode: response.statusCode,
      body: response.body,
      url: uri.toString(),
    );
  }

  Future<http.Response> postRaw(Uri uri, String body) async {
    final response = await _httpClient
        .post(
          uri,
          body: utf8.encode(body),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
        )
        .timeout(_timeout);
    return response;
  }

  Future<Map<String, dynamic>> post(
    String method, {
    Map<String, String>? params,
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(method, params ?? {});
    final encodedBody = body != null ? jsonEncode(body) : null;
    late http.Response response;
    try {
      response = await _httpClient
          .post(uri, body: encodedBody, headers: {'Content-Type': 'application/json; charset=utf-8'})
          .timeout(_timeout);
    } on TimeoutException {
      // Reuse the same signed URL and transact_key for an idempotent retry.
      response = await _httpClient
          .post(uri, body: encodedBody, headers: {'Content-Type': 'application/json; charset=utf-8'})
          .timeout(_timeout);
    }
    try {
      return _handleResponse(response);
    } on ApiException catch (e) {
      _notifyAuthExpired(e);
      rethrow;
    }
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
      throw ApiException(
        err['error_message']?.toString() ?? 'Unknown API error',
        err['error_code']?.toString() ?? 'API_ERROR',
      );
    }
    
    if (resp != null && resp.containsKey('response_data')) {
      final data = resp['response_data'];
      if (data is Map<String, dynamic> && data.containsKey('errors')) {
        final errors = data['errors'] as List<dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          final first = errors.first as Map<String, dynamic>;
          throw ApiException(
            first['text']?.toString() ?? 'API error',
            first['code']?.toString() ?? 'API_ERROR',
          );
        }
      }
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

class DebugResponse {
  final int statusCode;
  final String body;
  final String url;
  final Map<String, String>? headers;
  DebugResponse({required this.statusCode, required this.body, required this.url, this.headers});
}
