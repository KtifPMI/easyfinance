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
}
