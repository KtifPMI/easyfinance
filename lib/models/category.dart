class Category {
  final String id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final String? parentId;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon = 'help',
    this.color = '#6B7280',
    this.parentId,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['title']?.toString() ?? '',
    type: _parseType(json['type']),
    icon: json['icon']?.toString() ?? 'help',
    color: json['color']?.toString() ?? '#6B7280',
    parentId: json['parent_id']?.toString(),
  );

  static String _parseType(dynamic type) {
    if (type is String) return type;
    if (type is int) return type == -1 ? 'expense' : type == 1 ? 'income' : 'other';
    return 'expense';
  }
}
