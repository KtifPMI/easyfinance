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
  final int? repeatCount; // fixed number of occurrences (count mode); null = unlimited
  final String? time; // 'HH:MM:SS' from the server, if any
  final List<String> acceptedDates; // 'YYYY-MM-DD' occurrences already confirmed
  final Map<String, String> occurrenceIds; // 'YYYY-MM-DD' -> server occurrence id (per-date)

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
    this.repeatCount,
    this.time,
    this.acceptedDates = const [],
    this.occurrenceIds = const {},
  });

  bool get isRepeating => repeatMode > 0;

  bool isAcceptedOn(String ymd) => acceptedDates.contains(ymd);

  /// All occurrence dates of this event inside the given [month].
  List<DateTime> occurrencesInMonth(DateTime month) {
    final year = month.year;
    final mon = month.month;
    final daysInMonth = DateTime(year, mon + 1, 0).day;
    final List<DateTime> result = [];

    final start = dateStart != null ? _parseDate(dateStart) : null;
    final upper = effectiveEndDate();

    // Skip whole months outside the [start, upper] window.
    if (upper != null && DateTime(year, mon).isAfter(DateTime(upper.year, upper.month))) {
      return result;
    }
    if (start != null && DateTime(year, mon).isBefore(DateTime(start.year, start.month))) {
      return result;
    }

    void add(int d) {
      if (d >= 1 && d <= daysInMonth) {
        final dt = DateTime(year, mon, d);
        if (start != null && dt.isBefore(start)) return;
        if (upper != null && dt.isAfter(upper)) return;
        result.add(dt);
      }
    }

    if (repeatMode == 0) {
      // One-time event: anchor date or specific date.
      final anchor = _parseDate(specificDate) ?? _parseDate(date);
      if (anchor != null && anchor.year == year && anchor.month == mon) add(anchor.day);
      return result;
    }

    switch (repeatMode) {
      case 1: // daily
        for (int d = 1; d <= daysInMonth; d++) {
          add(d);
        }
        break;
      case 7: // weekly — use the selected weekdays bitmask when present
        if (weekDays != null && weekDays!.length == 7) {
          for (int d = 1; d <= daysInMonth; d++) {
            if (weekDays![DateTime(year, mon, d).weekday - 1] == '1') add(d);
          }
        } else {
          final anchor = _parseDate(dateStart) ?? _parseDate(date);
          if (anchor != null) {
            final wd = anchor.weekday;
            for (int d = 1; d <= daysInMonth; d++) {
              if (DateTime(year, mon, d).weekday == wd) add(d);
            }
          }
        }
        break;
      case 30: // monthly by day of month
        add(dayOfMonth ?? _parseDate(dateStart)?.day ?? _parseDate(date)?.day ?? 1);
        break;
      case 90: // quarterly
        final anchor = _parseDate(dateStart) ?? _parseDate(date);
        if (anchor != null && ((mon - anchor.month) % 3 + 12) % 12 == 0) {
          add(anchor.day > daysInMonth ? daysInMonth : anchor.day);
        }
        break;
      case 365: // yearly
        final anchor = _parseDate(dateStart) ?? _parseDate(date);
        if (anchor != null && anchor.month == mon) add(anchor.day > daysInMonth ? daysInMonth : anchor.day);
        break;
      default:
        add(dayOfMonth ?? _parseDate(dateStart)?.day ?? _parseDate(date)?.day ?? 1);
    }
    return result;
  }

  /// Upper bound for occurrences: explicit `dateEnd`, or the last occurrence
  /// date derived from a fixed `repeatCount` (count mode).
  DateTime? effectiveEndDate() {
    if (dateEnd != null && dateEnd!.isNotEmpty && dateEnd != '0000-00-00') {
      return _parseDate(dateEnd);
    }
    if (repeatCount == null || repeatCount! <= 0) return null;
    final start = _parseDate(dateStart) ?? _parseDate(date);
    if (start == null) return null;
    DateTime first = start;
    if (repeatMode == 7 && weekDays != null && weekDays!.length == 7) {
      int guard = 0;
      while (guard < 8 && weekDays![first.weekday - 1] != '1') {
        first = first.add(const Duration(days: 1));
        guard++;
      }
    }
    switch (repeatMode) {
      case 1:
        return first.add(Duration(days: repeatCount! - 1));
      case 7:
        return first.add(Duration(days: 7 * (repeatCount! - 1)));
      case 30:
        return DateTime(first.year, first.month + (repeatCount! - 1), first.day);
      case 90:
        return DateTime(first.year, first.month + 3 * (repeatCount! - 1), first.day);
      case 365:
        return DateTime(first.year + (repeatCount! - 1), first.month, first.day);
      default:
        return first;
    }
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

  /// Most recent occurrence on or before [before] (inclusive), within 3 years back.
  DateTime? lastOccurrence({DateTime? before}) {
    final today = before ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (int i = 0; i < 36; i++) {
      final m = DateTime(today.year, today.month - i, 1);
      final occ = occurrencesInMonth(m);
      DateTime? best;
      for (final d in occ) {
        if (!d.isAfter(today) && (best == null || d.isAfter(best))) best = d;
      }
      if (best != null) return best;
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
    if (repeatCount != null) 'repeatCount': repeatCount,
    if (time != null) 'time': time,
    'acceptedDates': acceptedDates,
    'occurrenceIds': occurrenceIds,
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
    repeatCount: json['repeatCount'] as int?,
    time: json['time'] as String?,
    acceptedDates: (json['acceptedDates'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    occurrenceIds: (json['occurrenceIds'] as Map<dynamic, dynamic>?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? const {},
  );
}
