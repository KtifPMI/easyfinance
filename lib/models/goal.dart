class Goal {
  final String id;
  final String title;
  final double targetAmount;
  double currentAmount;
  final String deadline;
  final String icon;
  final String color;
  final double? monthlyRecommendation;
  bool isCompleted;
  final String? accountId;
  final String? transferAccountId;

  Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.deadline,
    this.icon = 'star',
    this.color = '#16A34A',
    this.monthlyRecommendation,
    this.isCompleted = false,
    this.accountId,
    this.transferAccountId,
  });

  factory Goal.fromJson(Map<String, dynamic> json, {Map<String, double>? accountBalances}) {
    final amount = double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0;
    final amountDone = double.tryParse(json['amount_done']?.toString() ?? '0') ?? 0.0;
    final endStr = json['end']?.toString() ?? '';
    final parts = endStr.split('.');
    final deadline = parts.length == 3 && parts[2].length == 4
        ? '${parts[2]}-${parts[1]}-${parts[0]}'
        : endStr;
    final accountsList = json['accounts'] as List<dynamic>?;
    final accountId = json['account']?.toString() ?? (accountsList?.isNotEmpty == true ? (accountsList!.first as Map<String, dynamic>)['account_id']?.toString() : null);
    return Goal(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      targetAmount: amount,
      currentAmount: amountDone,
      deadline: deadline,
      icon: 'star',
      color: '#16A34A',
      isCompleted: (json['done']?.toString() == '1') || (amount > 0 && amountDone >= amount),
      accountId: accountId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'targetAmount': targetAmount,
    'currentAmount': currentAmount,
    'deadline': deadline,
    'icon': icon,
    'color': color,
    'monthlyRecommendation': monthlyRecommendation,
    'isCompleted': isCompleted,
    'accountId': accountId,
    'transferAccountId': transferAccountId,
  };

  factory Goal.fromOpPattern(Map<String, dynamic> json) {
    final amount = double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0;
    final amountDone = double.tryParse(json['amount_done']?.toString() ?? '0') ?? 0.0;
    return Goal(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? '',
      targetAmount: amount,
      currentAmount: amountDone,
      deadline: json['end']?.toString() ?? '',
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
    deadline: json['deadline'] as String? ?? '',
    icon: json['icon'] as String? ?? 'star',
    color: json['color'] as String? ?? '#16A34A',
    monthlyRecommendation: (json['monthlyRecommendation'] as num?)?.toDouble(),
    isCompleted: json['isCompleted'] as bool? ?? false,
    accountId: json['accountId'] as String?,
    transferAccountId: json['transferAccountId'] as String?,
  );

  Goal copyWith({double? currentAmount, bool? isCompleted}) =>
      Goal(
        id: id, title: title, targetAmount: targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        deadline: deadline, icon: icon, color: color,
        monthlyRecommendation: monthlyRecommendation,
        isCompleted: isCompleted ?? this.isCompleted,
        accountId: accountId, transferAccountId: transferAccountId,
      );
}
