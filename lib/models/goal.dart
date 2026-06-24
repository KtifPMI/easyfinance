class Goal {
  final String id;
  final String title;
  final double targetAmount;
  double currentAmount;
  final String deadline;
  final String icon;
  final String color;
  final double? monthlyRecommendation;

  Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.deadline,
    this.icon = 'star',
    this.color = '#16A34A',
    this.monthlyRecommendation,
  });

  Goal copyWith({double? currentAmount}) =>
      Goal(id: id, title: title, targetAmount: targetAmount, currentAmount: currentAmount ?? this.currentAmount, deadline: deadline, icon: icon, color: color, monthlyRecommendation: monthlyRecommendation);
}
