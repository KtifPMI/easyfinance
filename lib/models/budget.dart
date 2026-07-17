class Budget {
  final String id;
  final String? name;
  final String categoryId;
  final double limit;
  double spent;
  final String period;
  final bool isDeleted;

  Budget({
    required this.id,
    this.name,
    required this.categoryId,
    required this.limit,
    this.spent = 0,
    this.period = 'monthly',
    this.isDeleted = false,
  });

  Budget copyWith({double? spent, bool? isDeleted, double? limit}) =>
      Budget(id: id, name: name, categoryId: categoryId, limit: limit ?? this.limit, spent: spent ?? this.spent, period: period, isDeleted: isDeleted ?? this.isDeleted);
}
