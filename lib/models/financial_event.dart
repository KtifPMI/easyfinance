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
  final String? toAccountId;
  final String? categoryId;
  final String? tags;
  final int repeatMode;
  final String? serverId;
  final String? chain; // 0=none, 1=daily, 7=weekly, 30=monthly, 90=quarterly, 365=yearly
  final String? weekDays; // 7 chars, Mon..Sun, '1'/'0'
  final String? dateStart;
  final String? dateEnd;
  final List<String> acceptedDates; // 'YYYY-MM-DD' occurrences already confirmed

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
    this.toAccountId,
    this.categoryId,
    this.tags,
    this.repeatMode = 0,
    this.serverId,
    this.chain,
    this.weekDays,
    this.dateStart,
    this.dateEnd,
    this.acceptedDates = const [],
  });

  bool get isRepeating => repeatMode > 0;

  bool isAcceptedOn(String ymd) => acceptedDates.contains(ymd);

  /// All occurrence dates of this event inside the given [month].
  List<DateTime> occurrencesInMonth(DateTime month) {
    final year = month.year;
    final mon = month.month;
    final daysInMonth = DateTime(year, mon + 1, 0).day;
    final List<DateTime> result = [];

    void add(int d) {
      if (d >= 1 && d <= daysInMonth) result.add(DateTime(year, mon, d));
    }

    if (repeatMode == 0) {
      // One-time event: anchor date or specific date.
      final anchor = _parseDate(specificDate) ?? _parseDate(date);
      if (anchor != null && anchor.year == year && anchor.month == mon) add(anchor.day);
      return result;
    }

    switch (repeatMode) {
      case 1: // daily
        for (int d = 1; d <= daysInMonth; d++) add(d);
        break;
      case 7: // weekly — same weekday as the anchor date
        final anchor = _parseDate(date);
        if (anchor != null) {
          final wd = anchor.weekday;
          for (int d = 1; d <= daysInMonth; d++) {
            if (DateTime(year, mon, d).weekday == wd) add(d);
          }
        }
        break;
      case 30: // monthly by day of month
        add(dayOfMonth ?? _parseDate(date)?.day ?? 1);
        break;
      case 90: // quarterly
        final anchor = _parseDate(date);
        if (anchor != null && ((mon - anchor.month) % 3 + 12) % 12 == 0) {
          add(anchor.day > daysInMonth ? daysInMonth : anchor.day);
        }
        break;
      case 365: // yearly
        final anchor = _parseDate(date);
        if (anchor != null && anchor.month == mon) add(anchor.day > daysInMonth ? daysInMonth : anchor.day);
        break;
      default:
        add(dayOfMonth ?? _parseDate(date)?.day ?? 1);
    }
    return result;
  }

  /// Next future occurrence on or after [from] (inclusive), within 3 years.
  DateTime? nextOccurrence({DateTime? from}) {
    final today = from ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (int i = 0; i < 36; i++) {
      final m = DateTime(today.year, today.month + i, 1);
      final occ = occurrencesInMonth(m);
      for (final d in occ) {
        if (!d.isBefore(today)) return d;
      }
    }
    return null;
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
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
    if (toAccountId != null) 'toAccountId': toAccountId,
    if (categoryId != null) 'categoryId': categoryId,
    if (tags != null) 'tags': tags,
    'repeatMode': repeatMode,
    if (serverId != null) 'serverId': serverId,
    if (chain != null) 'chain': chain,
    if (weekDays != null) 'weekDays': weekDays,
    if (dateStart != null) 'dateStart': dateStart,
    if (dateEnd != null) 'dateEnd': dateEnd,
    'acceptedDates': acceptedDates,
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
    toAccountId: json['toAccountId'] as String?,
    categoryId: json['categoryId'] as String?,
    tags: json['tags'] as String?,
    repeatMode: json['repeatMode'] as int? ?? 0,
    serverId: json['serverId'] as String?,
    chain: json['chain'] as String?,
    weekDays: json['weekDays'] as String?,
    dateStart: json['dateStart'] as String?,
    dateEnd: json['dateEnd'] as String?,
    acceptedDates: (json['acceptedDates'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
  );
}
