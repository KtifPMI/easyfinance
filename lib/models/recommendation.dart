class Recommendation {
  final String id;
  final String title;
  final String description;
  final String type;
  final String severity;
  final double? amount;

  Recommendation({
    required this.id,
    required this.title,
    required this.description,
    this.type = 'tip',
    this.severity = 'low',
    this.amount,
  });
}
