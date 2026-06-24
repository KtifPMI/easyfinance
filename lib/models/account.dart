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
}
