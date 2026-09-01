import '../utils/currency_utils.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String login;
  final String accountType;
  final DateTime? tariffEnd;
  final String currency;
  final DateTime? registeredAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.login = '',
    this.accountType = 'individual',
    this.tariffEnd,
    this.currency = 'RUB',
    this.registeredAt,
  });

  bool get isPremium => tariffEnd != null && tariffEnd!.isAfter(DateTime.now());

  factory User.fromJson(Map<String, dynamic> json) {
    final tariffStr = json['tariff_duration']?.toString();
    DateTime? tariffEnd;
    if (tariffStr != null && tariffStr.isNotEmpty) {
      tariffEnd = DateTime.tryParse(tariffStr.replaceAll('  ', 'T'));
    }
    DateTime? registeredAt;
    final regStr = json['created_at']?.toString();
    if (regStr != null && regStr.isNotEmpty) {
      registeredAt = DateTime.tryParse(regStr.replaceAll('  ', 'T'));
    }
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      email: json['mail']?.toString() ?? json['email']?.toString() ?? '',
      login: json['login']?.toString() ?? '',
      accountType: json['account_type']?.toString() ?? 'individual',
      tariffEnd: tariffEnd,
      currency: currencyIdToCode[json['default_currency']?.toString()] ?? 'RUB',
      registeredAt: registeredAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'email': email, 'login': login,
    'account_type': accountType, 'currency': currency,
    'tariff_end': tariffEnd?.toIso8601String(),
    'created_at': registeredAt?.toIso8601String(),
  };
}
