const Map<String, String> _catIconMap = {
  'catimg1': 'food', 'catimg2': 'transport', 'catimg3': 'housing',
  'catimg4': 'shopping', 'catimg5': 'health', 'catimg6': 'entertainment',
  'catimg7': 'education', 'catimg8': 'travel', 'catimg9': 'salary',
  'catimg10': 'freelance', 'catimg11': 'business', 'catimg12': 'gift',
  'catimg13': 'car', 'catimg14': 'sports', 'catimg15': 'dining',
  'catimg16': 'utilities', 'catimg17': 'internet', 'catimg18': 'clothing',
  'catimg19': 'children', 'catimg20': 'pets', 'catimg21': 'taxes',
  'catimg22': 'insurance', 'catimg23': 'invest', 'catimg24': 'rent',
  'catimg25': 'other_income', 'catimg26': 'other_expense',
  'catimg27': 'transport', 'catimg28': 'sports', 'catimg29': 'dining',
  'catimg30': 'food', 'catimg31': 'shopping', 'catimg32': 'health',
  'catimg33': 'entertainment',
};

const Map<String, String> _catIconColor = {
  'catimg1': '#F59E0B', 'catimg2': '#3B82F6', 'catimg3': '#8B5CF6',
  'catimg4': '#EF4444', 'catimg5': '#14B8A6', 'catimg6': '#EC4899',
  'catimg7': '#0EA5E9', 'catimg8': '#A855F7', 'catimg9': '#16A34A',
  'catimg10': '#22C55E', 'catimg11': '#10B981', 'catimg12': '#059669',
  'catimg13': '#F97316', 'catimg14': '#E11D48', 'catimg15': '#F43F5E',
  'catimg16': '#6366F1', 'catimg17': '#06B6D4', 'catimg18': '#D946EF',
  'catimg19': '#84CC16', 'catimg20': '#78716C', 'catimg21': '#DC2626',
  'catimg22': '#2563EB', 'catimg23': '#059669', 'catimg24': '#7C3AED',
  'catimg25': '#16A34A', 'catimg26': '#6B7280',
};

class Category {
  final String id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final String? parentId;
  final bool isDefault;

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.icon = 'help',
    this.color = '#6B7280',
    this.parentId,
    this.isDefault = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final iconKey = json['icon']?.toString() ?? '';
    final custom = json['custom']?.toString() ?? '0';
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      type: _parseType(json['type']),
      icon: _catIconMap[iconKey] ?? iconKey,
      color: _catIconColor[iconKey] ?? '#6B7280',
      parentId: json['parent_id']?.toString(),
      isDefault: custom == '0',
    );
  }

  static String _parseType(dynamic type) {
    if (type is String) {
      if (type == '-1') return 'expense';
      if (type == '1') return 'income';
      return type;
    }
    if (type is int) return type == -1 ? 'expense' : type == 1 ? 'income' : 'other';
    return 'expense';
  }
}
