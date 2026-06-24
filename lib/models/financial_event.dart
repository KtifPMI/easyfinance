class FinancialEvent {
  final String id;
  final String title;
  final String date;
  final double? amount;
  final String type;
  final bool isRecurring;
  final String? recurrenceRule;

  FinancialEvent({
    required this.id,
    required this.title,
    required this.date,
    this.amount,
    this.type = 'reminder',
    this.isRecurring = false,
    this.recurrenceRule,
  });
}
