import '../models/account.dart';
import '../models/operation.dart';
import '../models/category.dart' as cat;
import '../models/user.dart';
import 'api_client.dart';

class ApiService {
  final ApiClient _client;
  ApiService(this._client);

  ApiClient get client => _client;

  Future<List<Account>> getAccounts() async {
    final json = await _client.get('accounts.get', params: {
      'fields': 'id,name,type_id,currency_id,state,balance,init_balance,description,created_at,updated_at,user_id',
    });
    return _parseList(json, 'accounts', Account.fromJson);
  }

  Future<List<Operation>> getOperations({String? from, String? to}) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final json = await _client.get('operations.get', params: params);
    return _parseList(json, 'operations', Operation.fromJson);
  }

  Future<List<cat.Category>> getCategories() async {
    final json = await _client.get('categories.get');
    return _parseList(json, 'categories', cat.Category.fromJson);
  }

  Future<BudgetInfo> getBudget() async {
    final json = await _client.get('budget.get');
    return _parseBudget(json);
  }

  Future<User> getUser() async {
    final json = await _client.get('users.get');
    final list = json['users'] as List<dynamic>?;
    if (list == null || list.isEmpty) throw ApiException('User not found', 'NOT_FOUND');
    return User.fromJson(list.first as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> addAccount(Map<String, dynamic> body, {String? options}) async {
    final params = <String, String>{};
    if (options != null) params['options'] = options;
    final json = await _client.post('accounts.post', params: params, body: {'request': {'request_info': {'method': 'accounts.post'}, 'request_data': body}});
    return json;
  }

  Future<void> setAccount(Map<String, dynamic> body) async {
    await _client.post('accounts.set', body: {'request': {'request_info': {'method': 'accounts.set'}, 'request_data': body}});
  }

  Future<Map<String, dynamic>> addOperation(Map<String, dynamic> body) async {
    final json = await _client.post('operations.post', body: {'request': {'request_data': body}});
    return json;
  }

  Future<void> setOperation(Map<String, dynamic> body) async {
    await _client.post('operations.set', body: {'request': {'request_data': body}});
  }

  Future<List<Map<String, dynamic>>> getGoals() async {
    final json = await _client.get('users.get', params: {'fields': 'goals'});
    final list = json['goals'] as List<dynamic>?;
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addCategory(Map<String, dynamic> body) async {
    final json = await _client.post('categories.post', body: {'request': {'request_info': {'method': 'categories.post'}, 'request_data': body}});
    return json;
  }

  Future<void> setCategory(Map<String, dynamic> body) async {
    await _client.post('categories.set', body: {'request': {'request_info': {'method': 'categories.set'}, 'request_data': body}});
  }

  List<T> _parseList<T>(Map<String, dynamic> data, String key, T Function(Map<String, dynamic>) fromJson) {
    final list = data[key] as List<dynamic>?;
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>().map(fromJson).toList();
  }

  BudgetInfo _parseBudget(Map<String, dynamic> data) {
    final budget = data['budget'] as Map<String, dynamic>?;
    final planned = double.tryParse(budget?['planned']?.toString() ?? '0') ?? 0;
    final spent = double.tryParse(budget?['spent']?.toString() ?? '0') ?? 0;
    return BudgetInfo(planned: planned, spent: spent);
  }
}

class BudgetInfo {
  final double planned;
  final double spent;
  BudgetInfo({required this.planned, required this.spent});
}
