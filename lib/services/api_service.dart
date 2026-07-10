import '../models/account.dart';
import '../models/operation.dart';
import '../models/category.dart' as cat;
import '../models/user.dart';
import '../models/tag.dart';
import '../models/operation_template.dart';
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

  Future<List<Tag>> getTags() async {
    final json = await _client.get('tags.get');
    return _parseList(json, 'tags', Tag.fromJson);
  }

  Future<List<OperationTemplate>> getTemplates() async {
    final json = await _client.get('operationPatterns.get');
    return _parseList(json, 'operationPatterns', OperationTemplate.fromJson);
  }

  Future<Map<String, dynamic>> addTemplate(Map<String, dynamic> body, {String? options}) async {
    final params = <String, String>{};
    if (options != null) params['options'] = options;
    final json = await _client.post('operationPatterns.post', params: params, body: {'request': {'request_data': body}});
    return json;
  }

  Future<void> setTemplate(Map<String, dynamic> body, {required String operationPatternId}) async {
    await _client.post('operationPatterns.set', params: {'operation_pattern_id': operationPatternId}, body: {'request': {'request_data': body}});
  }

  Future<List<Map<String, dynamic>>> getCurrencies() async {
    final json = await _client.get('currencies.get');
    final list = json['currencies'] as List<dynamic>?;
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getSystemCategories() async {
    final json = await _client.get('systemCategories.get');
    final list = json['systemCategories'] as List<dynamic>?;
    if (list == null) return [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addCategory(Map<String, dynamic> body, {String? options}) async {
    final params = <String, String>{};
    if (options != null) params['options'] = options;
    final json = await _client.post('categories.post', params: params, body: {'request': {'request_data': body}});
    return json;
  }

  Future<void> setCategory(Map<String, dynamic> body, {required String categoryId, String? options}) async {
    final params = <String, String>{'category_id': categoryId};
    if (options != null) params['options'] = options;
    await _client.post('categories.set', params: params, body: {'request': {'request_data': body}});
  }

  Future<Map<String, dynamic>> addAccount(Map<String, dynamic> body, {String? options}) async {
    final params = <String, String>{};
    if (options != null) params['options'] = options;
    final json = await _client.post('accounts.post', params: params, body: {'request': {'request_data': body}});
    return json;
  }

  Future<void> setAccount(Map<String, dynamic> body, {required String accountId}) async {
    await _client.post('accounts.set', params: {'account_id': accountId}, body: {'request': {'request_data': body}});
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

  Future<List<Map<String, dynamic>>> getGoalTemplates() async {
    final json = await _client.get('operationPatterns.get');
    final list = json['operationPatterns'] as List<dynamic>?;
    if (list == null) return [];
    return list
        .cast<Map<String, dynamic>>()
        .where((m) {
          final t = m['type'];
          return (t is String && t == '4') || (t is int && t == 4);
        })
        .toList();
  }

  Future<Map<String, dynamic>> addGoalTemplate(Map<String, dynamic> body) async {
    final json = await _client.post('operationPatterns.post', params: {'options': 'client'}, body: {'request': {'request_data': body}});
    return json;
  }

  Future<void> setGoalTemplate(Map<String, dynamic> body, {required String id}) async {
    await _client.post('operationPatterns.set', params: {'operation_pattern_id': id}, body: {'request': {'request_data': body}});
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
    final dateStart = budget?['date_start']?.toString() ?? '';
    final dateEnd = budget?['date_end']?.toString() ?? '';
    return BudgetInfo(planned: planned, spent: spent, dateStart: dateStart, dateEnd: dateEnd);
  }
}

class BudgetInfo {
  final double planned;
  final double spent;
  final String dateStart;
  final String dateEnd;
  BudgetInfo({required this.planned, required this.spent, this.dateStart = '', this.dateEnd = ''});
}
