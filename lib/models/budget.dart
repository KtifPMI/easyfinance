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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category_id': categoryId,
    'limit': limit,
    'spent': spent,
    'period': period,
    'is_deleted': isDeleted,
  };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString(),
    categoryId: json['category_id']?.toString() ?? '',
    limit: (json['limit'] as num?)?.toDouble() ?? 0,
    spent: (json['spent'] as num?)?.toDouble() ?? 0,
    period: json['period']?.toString() ?? 'monthly',
    isDeleted: json['is_deleted'] == true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Budget &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          categoryId == other.categoryId &&
          limit == other.limit &&
          spent == other.spent &&
          period == other.period &&
          isDeleted == other.isDeleted;

  @override
  int get hashCode => Object.hash(id, name, categoryId, limit, spent, period, isDeleted);
}
