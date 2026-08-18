class Goal {
  final String id;
  final String title;
  final double targetAmount;
  double currentAmount;
  final String startDate;
  final String deadline;
  final String icon;
  final String color;
  final double? monthlyRecommendation;
  bool isCompleted;
  final String? accountId;
  final String? transferAccountId;
  final String? currencyId;
  final String? comment;
  final String? category;
  final int? goalType;
  final int? goalState;
  final List<String> accountIds;

  Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0,
    this.startDate = '',
    required this.deadline,
    this.icon = 'star',
    this.color = '#16A34A',
    this.monthlyRecommendation,
    this.isCompleted = false,
    this.accountId,
    this.transferAccountId,
    this.currencyId,
    this.comment,
    this.category,
    this.goalType,
    this.goalState,
    this.accountIds = const [],
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    final amount = double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0;
    final amountDone = double.tryParse(json['amount_done']?.toString() ?? '0') ?? 0.0;
    final startDate = _normalizeDate(json['date_begin'] ?? json['start']);
    final deadline = _normalizeDate(json['date_end'] ?? json['end']);

    final accountsList = json['accounts'] as List<dynamic>?;
    final List<String> parsedAccounts = [];
    if (accountsList != null) {
      for (final a in accountsList) {
        if (a is Map) {
          final aid = a['account_id']?.toString();
          if (aid != null && aid != '0') parsedAccounts.add(aid);
        } else {
          final aid = a?.toString();
          if (aid != null && aid != '0') parsedAccounts.add(aid);
        }
      }
    }
    final directAccountId = json['account_id']?.toString();
    String? singleAccountId;
    if (parsedAccounts.isNotEmpty) {
      singleAccountId = parsedAccounts.first;
    } else if (directAccountId != null && directAccountId != '0') {
      singleAccountId = directAccountId;
      parsedAccounts.add(directAccountId);
    }

    return Goal(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      targetAmount: amount,
      currentAmount: amountDone,
      startDate: startDate,
      deadline: deadline,
      icon: 'star',
      color: '#16A34A',
      isCompleted: (json['done']?.toString() == '1') || (amount > 0 && amountDone >= amount),
      accountId: singleAccountId,
      accountIds: parsedAccounts,
      currencyId: json['currency_id']?.toString(),
      comment: json['comment']?.toString(),
      category: json['category_id']?.toString(),
      goalType: int.tryParse(json['type']?.toString() ?? ''),
      goalState: int.tryParse(json['state']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'targetAmount': targetAmount,
    'currentAmount': currentAmount,
    'startDate': startDate,
    'deadline': deadline,
    'icon': icon,
    'color': color,
    'monthlyRecommendation': monthlyRecommendation,
    'isCompleted': isCompleted,
    'accountId': accountId,
    'accountIds': accountIds,
    'transferAccountId': transferAccountId,
    'currencyId': currencyId,
    'comment': comment,
    'category': category,
    'goalType': goalType,
    'goalState': goalState,
  };

  factory Goal.fromOpPattern(Map<String, dynamic> json) {
    final amount = double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0;
    final amountDone = double.tryParse(json['amount_done']?.toString() ?? '0') ?? 0.0;
    return Goal(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? '',
      targetAmount: amount,
      currentAmount: amountDone,
      startDate: _normalizeDate(json['date_begin'] ?? json['start']),
      deadline: _normalizeDate(json['date_end'] ?? json['end']),
      icon: 'star',
      color: '#16A34A',
      isCompleted: amount > 0 && amountDone >= amount,
      accountId: json['account_id']?.toString(),
    );
  }

  factory Goal.fromLocalJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
    currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
    startDate: json['startDate'] as String? ?? '',
    deadline: json['deadline'] as String? ?? '',
    icon: json['icon'] as String? ?? 'star',
    color: json['color'] as String? ?? '#16A34A',
    monthlyRecommendation: (json['monthlyRecommendation'] as num?)?.toDouble(),
    isCompleted: json['isCompleted'] as bool? ?? false,
    accountId: json['accountId'] as String?,
    transferAccountId: json['transferAccountId'] as String?,
    currencyId: json['currencyId'] as String?,
    comment: json['comment'] as String?,
    category: json['category'] as String?,
    goalType: (json['goalType'] as num?)?.toInt(),
    goalState: (json['goalState'] as num?)?.toInt(),
    accountIds: (json['accountIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
  );

  Goal copyWith({double? currentAmount, bool? isCompleted, String? title, double? targetAmount, String? deadline, String? startDate, String? accountId, List<String>? accountIds, String? currencyId, String? comment, String? category, int? goalType, int? goalState}) =>
      Goal(
        id: id, title: title ?? this.title, targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        startDate: startDate ?? this.startDate,
        deadline: deadline ?? this.deadline, icon: icon, color: color,
        monthlyRecommendation: monthlyRecommendation,
        isCompleted: isCompleted ?? this.isCompleted,
        accountId: accountId ?? this.accountId,
        accountIds: accountIds ?? this.accountIds,
        transferAccountId: transferAccountId,
        currencyId: currencyId ?? this.currencyId,
        comment: comment ?? this.comment,
        category: category ?? this.category,
        goalType: goalType ?? this.goalType,
        goalState: goalState ?? this.goalState,
      );

  double balanceFrom(Map<String, double>? balances) {
    if (accountIds.isEmpty) return currentAmount;
    if (balances == null) return currentAmount;
    double sum = 0;
    for (final id in accountIds) {
      sum += balances[id] ?? 0;
    }
    return sum;
  }

  double progressAmount(Map<String, double>? balances) {
    final bal = balanceFrom(balances);
    if (goalType == 2) {
      final remaining = -bal;
      return targetAmount - (remaining < 0 ? 0 : remaining);
    }
    return bal;
  }

  bool achieved(Map<String, double>? balances) {
    final bal = balanceFrom(balances);
    if (goalType == 2) return bal >= 0;
    return bal >= targetAmount;
  }

  double percent(Map<String, double>? balances) {
    if (targetAmount <= 0) return 0;
    final p = progressAmount(balances) / targetAmount * 100;
    return p < 0 ? 0 : (p > 100 ? 100 : p);
  }

  static String _normalizeDate(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty || raw == '0000-00-00') return '';
    final iso = DateTime.tryParse(raw);
    if (iso != null) {
      return '${iso.year.toString().padLeft(4, '0')}-${iso.month.toString().padLeft(2, '0')}-${iso.day.toString().padLeft(2, '0')}';
    }
    final parts = raw.split('.');
    if (parts.length == 3 && parts[2].length == 4) {
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
    return '';
  }
}
