import 'pda_api_client.dart';

class PdaApiService {
  final PdaApiClient _client;
  PdaApiService(this._client);

  PdaApiClient get client => _client;

  /// target/get — get all goals
  Future<List<Map<String, dynamic>>> getTargets() async {
    final json = await _client.post('target/get');
    final list = json['target'] as List<dynamic>?;
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }

  /// target/process — create or update a goal
  Future<Map<String, dynamic>> processTarget(Map<String, String> params) async {
    return await _client.post('target/process', params: params);
  }

  /// target/delete — delete a goal
  Future<void> deleteTarget(String id) async {
    await _client.post('target/delete', params: {'id': id});
  }

  /// budget/process — create or update a budget
  Future<Map<String, dynamic>> processBudget(Map<String, String> params) async {
    return await _client.post('budget/process', params: params);
  }

  /// currency/get — get currency rates
  Future<List<Map<String, dynamic>>> getCurrencies() async {
    final json = await _client.post('currency/get');
    final list = json['currency'] as List<dynamic>?;
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }

  /// report — get server-side report data
  Future<Map<String, dynamic>> getReport({String? from, String? to}) async {
    final params = <String, String>{};
    if (from != null) params['date_from'] = from;
    if (to != null) params['date_to'] = to;
    return await _client.post('report', params: params);
  }
}
