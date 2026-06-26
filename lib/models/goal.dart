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
  });

  Goal copyWith({double? currentAmount, bool? isCompleted}) =>
      Goal(
        id: id, title: title, targetAmount: targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        deadline: deadline, icon: icon, color: color,
        monthlyRecommendation: monthlyRecommendation,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}
