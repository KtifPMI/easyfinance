const Map<String, String> _currencyIdToCode = {
  '1': 'RUB', '2': 'USD', '3': 'EUR', '4': 'GBP', '5': 'CHF',
  '6': 'CNY', '7': 'JPY', '8': 'BYN', '9': 'UAH', '10': 'KZT',
  '11': 'PLN', '12': 'CZK', '13': 'SEK', '14': 'NOK',
};

const Map<String, String> _iconMap = {
  'accountimage1': 'cash', 'accountimage2': 'credit_card',
  'accountimage3': 'savings', 'accountimage4': 'account_balance',
  'accountimage5': 'wallet', 'accountimage6': 'payments',
  'accountimage7': 'currency_ruble', 'accountimage8': 'card_giftcard',
};

const Map<String, String> _iconColor = {
  'accountimage1': '#16A34A', 'accountimage2': '#FFD700',
  'accountimage3': '#FF9800', 'accountimage4': '#7C3AED',
  'accountimage5': '#F44336', 'accountimage6': '#00BCD4',
  'accountimage7': '#795548', 'accountimage8': '#607D8B',
};

class Account {
  final String id;
  final String name;
  double balance;
  final String currency;
  final String icon;
  final String color;
  final String type;
  final bool includeInTotal;
  final bool isArchived;
  final double initBalance;
  final String createdAt;
  final String updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.balance,
    this.currency = 'RUB',
    this.icon = 'cash',
    this.color = '#16A34A',
    this.type = 'account',
    this.includeInTotal = true,
    this.isArchived = false,
    this.initBalance = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  Account copyWith({String? id, double? balance}) =>
      Account(id: id ?? this.id, name: name, balance: balance ?? this.balance, currency: currency, icon: icon, color: color, type: type, includeInTotal: includeInTotal, isArchived: isArchived, initBalance: initBalance, createdAt: createdAt, updatedAt: updatedAt);

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'balance': balance, 'currency': currency,
    'icon': icon, 'color': color, 'type': type,
    'include_in_total': includeInTotal, 'is_archived': isArchived,
    'init_balance': initBalance, 'created_at': createdAt, 'updated_at': updatedAt,
  };

  factory Account.fromLocalJson(Map<String, dynamic> json) => Account(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    balance: (json['balance'] as num?)?.toDouble() ?? 0,
    currency: json['currency']?.toString() ?? 'RUB',
    icon: json['icon']?.toString() ?? 'cash',
    color: json['color']?.toString() ?? '#16A34A',
    type: json['type']?.toString() ?? 'account',
    includeInTotal: json['include_in_total'] == true,
    isArchived: json['is_archived'] == true,
    initBalance: (json['init_balance'] as num?)?.toDouble() ?? 0,
    createdAt: json['created_at']?.toString() ?? '',
    updatedAt: json['updated_at']?.toString() ?? '',
  );

  factory Account.fromJson(Map<String, dynamic> json) {
    final icon = json['icon']?.toString() ?? '';
    final state = int.tryParse(json['state']?.toString() ?? '0') ?? 0;
    final isArchived = state == 2;
    final initBalance = double.tryParse(json['init_balance']?.toString() ?? '0')?.abs() ?? 0;
    return Account(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      balance: double.tryParse(json['balance']?.toString() ?? '0')?.abs() ?? 0,
      currency: _currencyIdToCode[json['currency_id']?.toString()] ?? json['currency_char_code']?.toString() ?? 'RUB',
      icon: _iconMap[icon] ?? 'credit_card',
      color: _iconColor[icon] ?? '#16A34A',
      type: _parseAccountType(json['type_id']),
      includeInTotal: !isArchived && json['include_in_total']?.toString() != '0',
      isArchived: isArchived,
      initBalance: initBalance,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  static String _parseAccountType(dynamic typeId) {
    if (typeId == null) return 'account';
    final id = int.tryParse(typeId.toString()) ?? 0;
    switch (id) {
      case 1: return 'account';
      case 2: case 16: return 'card';
      case 8: return 'credit';
      case 5: return 'savings';
      case 15: return 'electronic';
      default: return 'account';
    }
  }
}
