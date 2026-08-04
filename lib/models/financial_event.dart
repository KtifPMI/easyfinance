class FinancialEvent {
  final String id;
  final String title;
  String date;
  final double amount;
  final String type;
  final String? comment;
  final bool isRecurring;
  final int? dayOfMonth;
  final String? specificDate;
  final bool enabled;
  final String? accountId;
  final String? categoryId;
  final String? tags;
  final int repeatMode;
  final String? serverId;
  final String? chain; // 0=none, 1=daily, 7=weekly, 30=monthly, 90=quarterly, 365=yearly

  FinancialEvent({
    required this.id,
    required this.title,
    required this.date,
    this.amount = 0,
    this.type = 'reminder',
    this.comment,
    this.isRecurring = false,
    this.dayOfMonth,
    this.specificDate,
    this.enabled = true,
    this.accountId,
    this.categoryId,
    this.tags,
    this.repeatMode = 0,
    this.serverId,
    this.chain,
  });

  bool get isRepeating => repeatMode > 0;

  DateTime nextOccurrence() {
    if (date.isNotEmpty) {
      final d = DateTime.tryParse(date);
      if (d != null) return d;
    }
    if (isRecurring && dayOfMonth != null) {
      final now = DateTime.now();
      var next = _dateForDay(now.year, now.month, dayOfMonth!);
      if (next.isBefore(DateTime(now.year, now.month, now.day))) {
        next = _dateForDay(now.year, now.month + 1, dayOfMonth!);
      }
      return next;
    }
    if (specificDate != null) {
      final d = DateTime.tryParse(specificDate!);
      if (d != null) return d;
    }
    return DateTime.now();
  }

  DateTime _dateForDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date,
    'amount': amount,
    'type': type,
    'comment': comment,
    'isRecurring': isRecurring,
    'dayOfMonth': dayOfMonth,
    'specificDate': specificDate,
    'enabled': enabled,
    if (accountId != null) 'accountId': accountId,
    if (categoryId != null) 'categoryId': categoryId,
    if (tags != null) 'tags': tags,
    'repeatMode': repeatMode,
    if (serverId != null) 'serverId': serverId,
    if (chain != null) 'chain': chain,
  };

  factory FinancialEvent.fromJson(Map<String, dynamic> json) => FinancialEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    date: json['date'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    type: json['type'] as String? ?? 'reminder',
    comment: json['comment'] as String?,
    isRecurring: json['isRecurring'] as bool? ?? false,
    dayOfMonth: json['dayOfMonth'] as int?,
    specificDate: json['specificDate'] as String?,
    enabled: json['enabled'] as bool? ?? true,
    accountId: json['accountId'] as String?,
    categoryId: json['categoryId'] as String?,
    tags: json['tags'] as String?,
    repeatMode: json['repeatMode'] as int? ?? 0,
    serverId: json['serverId'] as String?,
    chain: json['chain'] as String?,
  );
}
