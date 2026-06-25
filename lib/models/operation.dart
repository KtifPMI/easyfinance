class Operation {
  final String id;
  final String type;
  final double amount;
  final String currency;
  final String date;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final List<String>? tagIds;
  final String? comment;
  final bool isDeleted;

  Operation({
    required this.id,
    required this.type,
    required this.amount,
    this.currency = 'RUB',
    required this.date,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.tagIds,
    this.comment,
    this.isDeleted = false,
  });

  Operation copyWith({bool? isDeleted}) =>
      Operation(id: id, type: type, amount: amount, currency: currency, date: date, accountId: accountId, toAccountId: toAccountId, categoryId: categoryId, tagIds: tagIds, comment: comment, isDeleted: isDeleted ?? this.isDeleted);

  factory Operation.fromJson(Map<String, dynamic> json) => Operation(
    id: json['id']?.toString() ?? '',
    type: _parseOpType(json['type']),
    amount: _parseAmount(json['amount']?.toString() ?? json['sum']?.toString() ?? '0'),
    currency: json['currency_code']?.toString() ?? json['currency']?.toString() ?? 'RUB',
    date: json['date']?.toString() ?? DateTime.now().toIso8601String(),
    accountId: json['account_id']?.toString() ?? '',
    toAccountId: json['transfer_account_id']?.toString() ?? json['to_account_id']?.toString(),
    categoryId: json['category_id']?.toString(),
    tagIds: _parseTags(json['tags']),
    comment: json['comment']?.toString(),
    isDeleted: json['deleted_at'] != null,
  );

  static String _parseOpType(dynamic type) {
    if (type is String) {
      if (type == '-1') return 'expense';
      if (type == '1') return 'income';
      if (type == '0') return 'transfer';
      return type;
    }
    if (type is int) return type == -1 ? 'expense' : type == 1 ? 'income' : 'transfer';
    return 'expense';
  }

  static double _parseAmount(String amount) {
    final v = double.tryParse(amount) ?? 0;
    return v.abs();
  }

  static List<String>? _parseTags(dynamic tags) {
    if (tags is List) return tags.map((e) => e.toString()).toList();
    if (tags is String && tags.isNotEmpty) return tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return null;
  }
}
