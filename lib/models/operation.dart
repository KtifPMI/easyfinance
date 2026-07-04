const Map<String, String> _opCurrencyIdToCode = {
  '1': 'RUB', '2': 'USD', '3': 'EUR', '4': 'GBP', '5': 'CHF',
  '6': 'CNY', '7': 'JPY', '8': 'BYN', '9': 'UAH', '10': 'KZT',
  '11': 'PLN', '12': 'CZK', '13': 'SEK', '14': 'NOK',
};

class Operation {
  final String id;
  final String type;
  final double amount;
  final String currency;
  final String date;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? comment;
  final String? tags;
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
    this.comment,
    this.tags,
    this.isDeleted = false,
  });

  Operation copyWith({bool? isDeleted, String? tags}) =>
      Operation(id: id, type: type, amount: amount, currency: currency, date: date, accountId: accountId, toAccountId: toAccountId, categoryId: categoryId, comment: comment, tags: tags ?? this.tags, isDeleted: isDeleted ?? this.isDeleted);

  factory Operation.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date']?.toString() ?? '';
    final timeStr = json['time']?.toString() ?? '00:00:00';
    final dateTimeStr = dateStr.contains('T') ? dateStr : '${dateStr}T$timeStr';
    return Operation(
      id: json['id']?.toString() ?? '',
      type: _parseOpType(json['type']),
      amount: _parseAmount(json['amount']?.toString() ?? json['sum']?.toString() ?? '0'),
      currency: _opCurrencyIdToCode[json['currency_id']?.toString()] ?? json['currency_code']?.toString() ?? 'RUB',
      date: dateTimeStr,
      accountId: json['account_id']?.toString() ?? '',
      toAccountId: json['to_account_id']?.toString() ?? json['transfer_account_id']?.toString(),
      categoryId: json['category_id']?.toString(),
      comment: json['comment']?.toString(),
      tags: json['tags']?.toString(),
      isDeleted: json['deleted_at'] != null || json['state']?.toString() == '2',
    );
  }

  static String _parseOpType(dynamic type) {
    if (type is String) {
      if (type == '0') return 'expense';
      if (type == '1') return 'income';
      if (type == '2') return 'transfer';
      if (type == '-1') return 'expense';
      if (type == 'expense' || type == 'income' || type == 'transfer') return type;
      return 'expense';
    }
    if (type is int) return type == 0 ? 'expense' : type == 1 ? 'income' : 'transfer';
    return 'expense';
  }

  static double _parseAmount(String amount) {
    final v = double.tryParse(amount) ?? 0;
    return v.abs();
  }
}
