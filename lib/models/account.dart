class Account {
  final String id;
  final String name;
  double balance;
  final String currency;
  final String icon;
  final String color;
  final String type;
  final bool includeInTotal;

  Account({
    required this.id,
    required this.name,
    required this.balance,
    this.currency = 'RUB',
    this.icon = 'cash',
    this.color = '#16A34A',
    this.type = 'account',
    this.includeInTotal = true,
  });

  Account copyWith({double? balance}) =>
      Account(id: id, name: name, balance: balance ?? this.balance, currency: currency, icon: icon, color: color, type: type, includeInTotal: includeInTotal);

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? json['title']?.toString() ?? '',
    balance: double.tryParse(json['state']?.toString() ?? json['balance']?.toString() ?? '0') ?? 0,
    currency: json['currency_char_code']?.toString() ?? json['currency']?.toString() ?? 'RUB',
    icon: json['icon']?.toString() ?? 'cash',
    color: json['color']?.toString() ?? '#16A34A',
    type: _parseAccountType(json['type_id']),
    includeInTotal: json['include_in_total']?.toString() != '0',
  );

  static String _parseAccountType(dynamic typeId) {
    if (typeId == null) return 'account';
    final id = int.tryParse(typeId.toString()) ?? 0;
    switch (id) {
      case 1: return 'account';
      case 2: return 'card';
      case 3: return 'credit';
      default: return 'account';
    }
  }
}
