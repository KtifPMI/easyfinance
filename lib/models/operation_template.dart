class OperationTemplate {
  final String id;
  final String name;
  final String type;
  final double amount;
  final String? accountId;
  final String? categoryId;
  final String? toAccountId;
  final String? comment;
  final String? tags;
  final String createdAt;
  final String updatedAt;
  final bool isPending;

  OperationTemplate({
    required this.id,
    required this.name,
    required this.type,
    this.amount = 0,
    this.accountId,
    this.categoryId,
    this.toAccountId,
    this.comment,
    this.tags,
    this.createdAt = '',
    this.updatedAt = '',
    this.isPending = false,
  });

  factory OperationTemplate.fromJson(Map<String, dynamic> json) {
    return OperationTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: _parseType(json['type']),
      amount: double.tryParse(json['amount']?.toString() ?? '0')?.abs() ?? 0,
      accountId: json['account_id']?.toString(),
      categoryId: json['category_id']?.toString(),
      toAccountId: json['to_account_id']?.toString() ?? json['transfer_account_id']?.toString(),
      comment: json['comment']?.toString(),
      tags: json['tags']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      isPending: false,
    );
  }

  static String _parseType(dynamic type) {
    if (type is String) {
      if (type == '0') return 'expense';
      if (type == '1') return 'income';
      if (type == '2') return 'transfer';
      if (type == '4') return 'goal';
    }
    if (type is int) {
      if (type == 0) return 'expense';
      if (type == 1) return 'income';
      if (type == 2) return 'transfer';
      if (type == 4) return 'goal';
    }
    return 'expense';
  }

  bool get isGoal => type == 'goal';

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type,
    'amount': amount,
    'account_id': accountId,
    'category_id': categoryId,
    'to_account_id': toAccountId,
    'comment': comment,
    'tags': tags,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'amount': amount,
    'accountId': accountId,
    'categoryId': categoryId,
    'toAccountId': toAccountId,
    'comment': comment,
    'tags': tags,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'is_pending': isPending,
  };

  OperationTemplate copyWith({String? id, String? name, String? type, double? amount, String? accountId, String? categoryId, String? toAccountId, String? comment, String? tags, String? createdAt, String? updatedAt, bool? isPending}) =>
      OperationTemplate(id: id ?? this.id, name: name ?? this.name, type: type ?? this.type, amount: amount ?? this.amount, accountId: accountId ?? this.accountId, categoryId: categoryId ?? this.categoryId, toAccountId: toAccountId ?? this.toAccountId, comment: comment ?? this.comment, tags: tags ?? this.tags, createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt, isPending: isPending ?? this.isPending);

  factory OperationTemplate.fromLocalJson(Map<String, dynamic> json) => OperationTemplate(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? 'expense',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    accountId: json['accountId'] as String?,
    categoryId: json['categoryId'] as String?,
    toAccountId: json['toAccountId'] as String?,
    comment: json['comment'] as String?,
    tags: json['tags'] as String?,
    createdAt: json['createdAt'] as String? ?? '',
    updatedAt: json['updatedAt'] as String? ?? '',
    isPending: json['is_pending'] == true,
  );
}
