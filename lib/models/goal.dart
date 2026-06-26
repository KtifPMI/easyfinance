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
    final amount = double.tryParse(json['amount']?.toString() ?? '0') ?? 0;
    final transferAmount = double.tryParse(json['transfer_amount']?.toString() ?? '0') ?? 0;
    final transferAccountId = json['transfer_account_id']?.toString();
    final currentAmount = transferAccountId != null && accountBalances != null
        ? (accountBalances[transferAccountId] ?? 0)
        : 0;
    return Goal(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? '',
      targetAmount: amount,
      currentAmount: currentAmount,
      deadline: '',
      icon: 'star',
      color: '#16A34A',
      monthlyRecommendation: transferAmount > 0 ? transferAmount : null,
      isCompleted: amount > 0 && currentAmount >= amount,
      accountId: json['account_id']?.toString(),
      transferAccountId: transferAccountId,
    );
  }

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
