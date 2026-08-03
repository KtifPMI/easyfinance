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

/// Full list ordered like the website: names with group headers.
const Map<int, String> accountTypeLabels = {
  // Данные
  1: 'accounts.type.cash',
  2: 'accounts.type.card',
  3: 'accounts.type.deposit',
  4: 'accounts.type.electronic',
  5: 'accounts.type.bank_account',
  // Долги
  7: 'accounts.type.loan_given',
  9: 'accounts.type.loan_received',
  10: 'accounts.type.credit_card',
  11: 'accounts.type.credit',
  // Инвестиции
  13: 'accounts.type.broker',
  14: 'accounts.type.oms',
  15: 'accounts.type.stocks',
  16: 'accounts.type.bonds',
  17: 'accounts.type.other_securities',
  18: 'accounts.type.pif',
  19: 'accounts.type.ofbu',
  20: 'accounts.type.fund',
  21: 'accounts.type.insurance_savings',
  22: 'accounts.type.savings_plan',
  23: 'accounts.type.npf',
  24: 'accounts.type.pension',
  25: 'accounts.type.pamm',
  // Имущество
  27: 'accounts.type.real_estate',
  28: 'accounts.type.car',
  29: 'accounts.type.water_transport',
  30: 'accounts.type.art',
  31: 'accounts.type.business',
  32: 'accounts.type.other_property',
  33: 'accounts.type.motorcycle',
  34: 'accounts.type.air_transport',
  // Карты лояльности
  36: 'accounts.type.bonus_card',
};

class Account {
  final String id;
  final String name;
  double balance;
  final String currency;
  final String? currencyId;
  final String icon;
  final String color;
  final String type;
  final bool includeInTotal;
  final bool isArchived;
  final bool isFavorite;
  final double initBalance;
  final String createdAt;
  final String updatedAt;

  final double? annualRate;
  final String? paymentType;
  final String? openDate;
  final String? closeDate;
  final double? commissionOneTime;
  final double? commissionMonthly;
  final int? paymentDay;
  final double? creditLimit;
  final String? description;
  final String? bankId;

  bool get isCredit => type == 'credit' || type == 'credit_card';

  Account({
    required this.id,
    required this.name,
    required this.balance,
    this.currency = 'RUB',
    this.currencyId,
    this.icon = 'cash',
    this.color = '#16A34A',
    this.type = 'account',
    this.includeInTotal = true,
    this.isArchived = false,
    this.isFavorite = false,
    this.initBalance = 0,
    this.createdAt = '',
    this.updatedAt = '',
    this.annualRate,
    this.paymentType,
    this.openDate,
    this.closeDate,
    this.commissionOneTime,
    this.commissionMonthly,
    this.paymentDay,
    this.creditLimit,
    this.description,
    this.bankId,
  });

  Account copyWith({String? id, double? balance, String? currencyId, bool? isFavorite}) =>
      Account(id: id ?? this.id, name: name, balance: balance ?? this.balance, currency: currency, currencyId: currencyId ?? this.currencyId, icon: icon, color: color, type: type, includeInTotal: includeInTotal, isArchived: isArchived, isFavorite: isFavorite ?? this.isFavorite, initBalance: initBalance, createdAt: createdAt, updatedAt: updatedAt, annualRate: annualRate, paymentType: paymentType, openDate: openDate, closeDate: closeDate, commissionOneTime: commissionOneTime, commissionMonthly: commissionMonthly, paymentDay: paymentDay, creditLimit: creditLimit, description: description, bankId: bankId);

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'balance': balance, 'currency': currency,
    'currency_id': currencyId, 'icon': icon, 'color': color, 'type': type,
    'include_in_total': includeInTotal, 'is_archived': isArchived,
    'is_favorite': isFavorite,
    'init_balance': initBalance, 'created_at': createdAt, 'updated_at': updatedAt,
    if (description != null && description!.isNotEmpty) 'description': description,
    if (bankId != null) 'bank_id': bankId,
    if (annualRate != null) 'annual_rate': annualRate,
    if (paymentType != null) 'payment_type': paymentType,
    if (openDate != null) 'open_date': openDate,
    if (closeDate != null) 'close_date': closeDate,
    if (commissionOneTime != null) 'commission_one_time': commissionOneTime,
    if (commissionMonthly != null) 'commission_monthly': commissionMonthly,
    if (paymentDay != null) 'payment_day': paymentDay,
    if (creditLimit != null) 'credit_limit': creditLimit,
  };

  factory Account.fromLocalJson(Map<String, dynamic> json) => Account(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    balance: (json['balance'] as num?)?.toDouble() ?? 0,
    currency: json['currency']?.toString() ?? 'RUB',
    currencyId: json['currency_id']?.toString(),
    icon: json['icon']?.toString() ?? 'cash',
    color: json['color']?.toString() ?? '#16A34A',
    type: json['type']?.toString() ?? 'account',
    includeInTotal: json['include_in_total'] == true,
    isArchived: json['is_archived'] == true,
    isFavorite: json['is_favorite'] == true,
    initBalance: (json['init_balance'] as num?)?.toDouble() ?? 0,
    createdAt: json['created_at']?.toString() ?? '',
    updatedAt: json['updated_at']?.toString() ?? '',
    description: json['description']?.toString(),
    bankId: json['bank_id']?.toString(),
    annualRate: (json['annual_rate'] as num?)?.toDouble(),
    paymentType: json['payment_type']?.toString(),
    openDate: json['open_date']?.toString(),
    closeDate: json['close_date']?.toString(),
    commissionOneTime: (json['commission_one_time'] as num?)?.toDouble(),
    commissionMonthly: (json['commission_monthly'] as num?)?.toDouble(),
    paymentDay: (json['payment_day'] as num?)?.toInt(),
    creditLimit: (json['credit_limit'] as num?)?.toDouble(),
  );

  factory Account.fromJson(Map<String, dynamic> json) {
    final icon = json['icon']?.toString() ?? '';
    final state = int.tryParse(json['state']?.toString() ?? '0') ?? 0;
    final isArchived = state == 2;
    final initBalance = double.tryParse(json['init_balance']?.toString() ?? '0') ?? 0;
    final currencyId = json['currency_id']?.toString();
    return Account(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0,
      currency: _currencyIdToCode[currencyId] ?? json['currency_char_code']?.toString() ?? 'RUB',
      currencyId: currencyId,
      icon: _iconMap[icon] ?? 'credit_card',
      color: _iconColor[icon] ?? '#16A34A',
      type: _parseAccountType(json['type_id']),
      includeInTotal: !isArchived && json['include_in_total']?.toString() != '0',
      isArchived: isArchived,
      initBalance: initBalance,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      description: json['description']?.toString(),
      bankId: json['bank_id']?.toString(),
      annualRate: double.tryParse(json['annual_rate']?.toString() ?? ''),
      paymentType: json['payment_type']?.toString(),
      openDate: json['open_date']?.toString(),
      closeDate: json['close_date']?.toString(),
      commissionOneTime: double.tryParse(json['commission_one_time']?.toString() ?? ''),
      commissionMonthly: double.tryParse(json['commission_monthly']?.toString() ?? ''),
      paymentDay: int.tryParse(json['payment_day']?.toString() ?? ''),
      creditLimit: double.tryParse(json['credit_limit']?.toString() ?? ''),
    );
  }

  static String _parseAccountType(dynamic typeId) {
    if (typeId == null) return 'account';
    final id = int.tryParse(typeId.toString()) ?? 0;
    switch (id) {
      case 1: return 'account';
      case 2: return 'card';
      case 3: return 'deposit';
      case 4: return 'electronic';
      case 5: return 'savings';
      case 7: return 'loan_given';
      case 8: return 'credit'; // legacy
      case 9: return 'loan_received';
      case 10: return 'credit_card';
      case 11: return 'credit';
      case 13: return 'broker';
      case 14: return 'oms';
      case 15: return 'stocks';
      case 16: return 'bonds';
      case 17: return 'other_securities';
      case 18: return 'pif';
      case 19: return 'ofbu';
      case 20: return 'fund';
      case 21: return 'insurance_savings';
      case 22: return 'savings_plan';
      case 23: return 'npf';
      case 24: return 'pension';
      case 25: return 'pamm';
      case 27: return 'real_estate';
      case 28: return 'car';
      case 29: return 'water_transport';
      case 30: return 'art';
      case 31: return 'business';
      case 32: return 'other_property';
      case 33: return 'motorcycle';
      case 34: return 'air_transport';
      case 36: return 'bonus_card';
      default: return 'account';
    }
  }
}

String groupForType(String type) {
  switch (type) {
    case 'account': case 'card': case 'deposit':
    case 'electronic': case 'savings':
      return 'money';
    case 'loan_received': case 'credit_card': case 'credit':
      return 'owed_by_me';
    case 'loan_given':
      return 'owed_to_me';
    case 'broker': case 'oms': case 'stocks': case 'bonds':
    case 'other_securities': case 'pif': case 'ofbu':
    case 'fund': case 'insurance_savings': case 'savings_plan':
    case 'npf': case 'pension': case 'pamm':
      return 'investments';
    case 'real_estate': case 'car': case 'water_transport':
    case 'art': case 'business': case 'other_property':
    case 'motorcycle': case 'air_transport':
      return 'property';
    case 'bonus_card':
      return 'loyalty';
    default:
      return 'money';
  }
}

const Map<String, int> groupOrder = {
  'money': 0,
  'owed_by_me': 1,
  'owed_to_me': 2,
  'investments': 3,
  'property': 4,
  'loyalty': 5,
};
