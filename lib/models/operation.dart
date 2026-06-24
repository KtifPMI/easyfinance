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
}
