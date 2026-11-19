import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/financial_event.dart';
import '../services/api_client.dart';
import '../services/account_cache.dart';
import '../services/notification_service.dart';

class PlannedPaymentStore extends ChangeNotifier {
  static const _key = 'easyfinance_planned_payments';
  final ApiClient _apiClient;
  List<FinancialEvent> _events = [];

  /// Resolves the server currency id of the account a planned payment belongs
  /// to. The calendar API does not accept a currency of its own and defaults
  /// to RUB when `currency_id` is missing, which used to store every planned
  /// payment in rubles even for USD/EUR accounts. `FinanceStore` wires this to
  /// its accounts list.
  String Function(String? accountId)? currencyIdResolver;

  PlannedPaymentStore({required ApiClient apiClient}) : _apiClient = apiClient;

  String get _cacheKey => AccountCache.key(_key, _apiClient.userId);

  List<FinancialEvent> get events => List.unmodifiable(_events);

  List<FinancialEvent> get upcomingEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = _events.where((e) {
      if (!e.enabled) return false;
      final next = e.nextOccurrence() ?? _dateOnly(e.date);
      return next != null && !next.isBefore(today);
    }).toList();
    result.sort((a, b) => (a.nextOccurrence() ?? today).compareTo(b.nextOccurrence() ?? today));
    return result;
  }

  /// Enabled events with an overdue (past, unconfirmed) occurrence, most overdue first.
  List<FinancialEvent> get overdueEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = _events.where((e) {
      if (!e.enabled) return false;
      final occ = e.lastOccurrence(before: today) ?? _dateOnly(e.date);
      if (occ == null || !occ.isBefore(today)) return false;
      return !e.isAcceptedOn(_ymd(occ));
    }).toList();
    result.sort((a, b) => (a.lastOccurrence(before: today) ?? today).compareTo(b.lastOccurrence(before: today) ?? today));
    return result;
  }

  List<FinancialEvent> get upcomingIncomes =>
      upcomingEvents.where((e) => e.type == 'income').toList();

  List<FinancialEvent> get upcomingExpenses =>
      upcomingEvents.where((e) => e.type == 'expense').toList();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _events = list.map((e) => FinancialEvent.fromJson(e as Map<String, dynamic>)).toList();
      _recalcDates();
    }
    notifyListeners();
  }

  /// Fetches planned payments from the API v2 and rebuilds server-backed events.
  ///
  /// The server returns every repeat occurrence as a separate entry (sharing a
  /// `chain_id`). We collapse them into ONE recurring [FinancialEvent] per
  /// chain so we don't create duplicate monthly series and so the chain's
  /// `date_end`/`acceptedDates` are preserved on the single event.
  /// Local-only events (no serverId) are always preserved.
  Future<void> syncFromServer() async {
    if (_apiClient.accessToken == null) return;
    try {
      final data = await _apiClient.getCalendarEventsV2();
      final collapsed = _collapseServerEvents(data);

      // Also fetch already-accepted occurrences so confirmed dates survive a
      // sync — once accepted, the server stops returning them in the default
      // (non-accepted) list, which would otherwise wipe the accepted state.
      try {
        final accepted = await _apiClient.getCalendarEventsV2(accepted: true);
        _mergeAcceptedDates(collapsed, accepted);
      } catch (e) {
        debugPrint('syncFromServer accepted error: $e');
      }

      final localOnly = _events.where((e) => e.serverId == null).toList();

      // Keep confirmation state that only exists locally (e.g. accepted while
      // offline, or when the `options=accepted` request above failed).
      final localByServerId = <String, FinancialEvent>{
        for (final e in _events)
          if (e.serverId != null) e.serverId!: e,
      };
      final localByChain = <String, FinancialEvent>{
        for (final e in _events)
          if (e.chain != null && e.chain!.isNotEmpty) e.chain!: e,
      };
      final merged = collapsed.map((e) {
        final local = localByServerId[e.serverId] ??
            (e.chain != null ? localByChain[e.chain!] : null);
        if (local == null) return e;
        final accepted = <String>{...e.acceptedDates, ...local.acceptedDates}.toList();
        final occurrenceIds = <String, String>{...e.occurrenceIds, ...local.occurrenceIds};
        return _copyEvent(e, acceptedDates: accepted, occurrenceIds: occurrenceIds);
      }).toList();

      // Replace all server-backed events with the freshly collapsed set,
      // keeping any local-only (never-synced) events untouched.
      _events = [...localOnly, ...merged];
      _recalcDates();
      await save();
      notifyListeners();
    } catch (e) {
      debugPrint('syncFromServer error: $e');
    }
  }

  /// Merges confirmed occurrence dates (fetched with `options=accepted`) into
  /// the matching collapsed [events] so acceptance is not lost on re-sync.
  void _mergeAcceptedDates(List<FinancialEvent> events, List<Map<String, dynamic>> accepted) {
    final byKey = <String, List<String>>{};
    for (final raw in accepted) {
      final id = raw['id']?.toString();
      if (id == null) continue;
      // The `options=accepted` list may contain every occurrence of a chain that
      // has at least one accepted item, each carrying its own `accepted` flag.
      // Only trust occurrences the server actually marks as accepted — otherwise
      // the whole series would be wrongly marked confirmed (see _eventFromGroup).
      final acceptedRaw = raw['accepted'];
      final isAccepted = acceptedRaw == 1 || acceptedRaw == '1' || acceptedRaw == true;
      if (!isAccepted) continue;
      final chain = raw['chain_id']?.toString();
      final key = (chain != null && chain.isNotEmpty && chain != '0') ? 'chain:$chain' : 'op:$id';
      final ad = _parseDate(raw['date']?.toString());
      if (ad.isNotEmpty) (byKey[key] ??= []).add(ad);
    }
    for (int i = 0; i < events.length; i++) {
      final dates = byKey[events[i].id];
      if (dates != null && dates.isNotEmpty) {
        final merged = <String>{...events[i].acceptedDates, ...dates}.toList();
        events[i] = _copyEvent(events[i], acceptedDates: merged);
      }
    }
  }

  /// Groups expanded server occurrences by `chain_id` (or by `id` when there is
  /// no chain) and returns a single [FinancialEvent] per group.
  List<FinancialEvent> _collapseServerEvents(List<Map<String, dynamic>> data) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final raw in data) {
      final id = raw['id']?.toString();
      if (id == null) continue;
      final chain = raw['chain_id']?.toString();
      final key = (chain != null && chain.isNotEmpty && chain != '0') ? 'chain:$chain' : 'op:$id';
      (groups[key] ??= []).add(raw);
    }
    return groups.entries.map((e) => _eventFromGroup(e.key, e.value)).toList();
  }

  FinancialEvent _eventFromGroup(String key, List<Map<String, dynamic>> entries) {
    final first = entries.first;
    final acceptedDates = <String>[];
    final occurrenceIds = <String, String>{};
    DateTime? earliestStart;
    String? earliestStartStr;
    String? dateEnd;
    int? everyDay;

    for (final e in entries) {
      final ds = e['date_start']?.toString() ?? e['date']?.toString();
      final d = _parseDate(ds).isNotEmpty ? DateTime.tryParse(_parseDate(ds)) : null;
      if (d != null && (earliestStart == null || d.isBefore(earliestStart))) {
        earliestStart = d;
        earliestStartStr = _parseDate(ds);
      }

      final de = e['date_end']?.toString();
      if (de != null && de.isNotEmpty && de != '0000-00-00') {
        final parsed = DateTime.tryParse(_parseDate(de));
        if (parsed != null && (dateEnd == null || parsed.isAfter(DateTime.tryParse(dateEnd)!))) {
          dateEnd = _parseDate(de);
        }
      }

      final ed = int.tryParse(e['every_day']?.toString() ?? e['every']?.toString() ?? '0') ?? 0;
      if (ed > 0) everyDay ??= ed;

      final acceptedRaw = e['accepted'];
      final accepted = acceptedRaw == 1 || acceptedRaw == '1' || acceptedRaw == true;
      if (accepted) {
        final ad = _parseDate(e['date']?.toString());
        if (ad.isNotEmpty) acceptedDates.add(ad);
      }
      final occId = e['id']?.toString();
      final occDate = _parseDate(e['date']?.toString());
      if (occId != null && occId.isNotEmpty && occDate.isNotEmpty) occurrenceIds[occDate] = occId;
    }

    final typeRaw = first['type']?.toString();
    final type = typeRaw == '1' ? 'income' : typeRaw == '2' ? 'transfer' : 'expense';
    final startDay = earliestStart?.day;
    final chain = key.startsWith('chain:') ? key.substring(6) : null;
    final serverId = first['id']?.toString();

    // Server `repeat`: "1" = one-time, "0" = repeat until `date_end`,
    // otherwise it is the number of occurrences (the series is expanded
    // server-side into that many discrete calendar entries).
    final repeatRaw = first['repeat']?.toString();
    final repeatRawNum = int.tryParse(repeatRaw ?? '');
    final period = repeatRaw == '1' ? 0 : (everyDay ?? 0);

    return FinancialEvent(
      id: key,
      title: first['comment']?.toString() ?? '',
      date: earliestStartStr ?? _parseDate(first['date']?.toString()),
      amount: (double.tryParse(first['amount']?.toString() ?? '0') ?? 0).abs(),
      type: type,
      comment: first['comment']?.toString(),
      isRecurring: period > 0,
      dayOfMonth: startDay,
      specificDate: null,
      enabled: true,
      accountId: first['account_id']?.toString(),
      toAccountId: first['transfer_account_id']?.toString(),
      categoryId: first['category_id']?.toString(),
      tags: first['tags']?.toString(),
      repeatMode: period,
      serverId: serverId,
      chain: chain,
      weekDays: first['week_days']?.toString(),
      dateStart: earliestStartStr,
      dateEnd: dateEnd,
      repeatCount: (period > 0 && repeatRawNum != null && repeatRawNum > 0) ? repeatRawNum : null,
      time: first['time']?.toString(),
      acceptedDates: acceptedDates,
      occurrenceIds: occurrenceIds,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_events.map((e) => e.toJson()).toList());
    await prefs.setString(_cacheKey, raw);
  }

  Future<void> add(FinancialEvent event) async {
    // Optimistic update: the server round-trip can take up to 10 seconds (and
    // fails completely offline), which used to make the app look like the
    // payment was never created. Show it immediately, sync afterwards.
    _events.add(event);
    _recalcDates();
    notifyListeners();
    await save();
    NotificationService().rescheduleAll();

    if (_apiClient.accessToken == null) return;
    final local = _events.firstWhere((e) => e.id == event.id, orElse: () => event);
    try {
      final resp = await _apiClient.postCalendarEventV2(_toCalendarBody(local));
      final serverId = _extractId(resp)?.toString();
      final chain = _extractChain(resp)?.toString();
      if (serverId != null) {
        final idx = _events.indexWhere((e) => e.id == event.id);
        if (idx != -1) {
          _events[idx] = _copyWithServer(_events[idx], serverId: serverId, chain: chain);
          await save();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('add calendar event error: $e');
    }
  }

  Future<void> update(String id, FinancialEvent updated) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    // Optimistic: apply locally first so the UI reacts instantly.
    _events[idx] = updated;
    _recalcDates();
    notifyListeners();
    await save();
    NotificationService().rescheduleAll();

    if (_apiClient.accessToken == null || updated.serverId == null) return;
    try {
      await _apiClient.setCalendarEventV2(updated.serverId!, updated.chain ?? '', _toCalendarBody(updated));
    } catch (e) {
      // Keep the local edit; the next sync will reconcile with the server.
      debugPrint('update calendar event error: $e');
    }
  }

  Future<void> remove(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final event = _events[idx];

    // Optimistic: remove locally first.
    _events.removeAt(idx);
    notifyListeners();
    await save();
    NotificationService().rescheduleAll();

    if (_apiClient.accessToken == null || event.serverId == null) return;
    try {
      await _apiClient.deleteCalendarEventV2(event.serverId!, event.chain ?? '');
    } catch (e) {
      debugPrint('delete calendar event error: $e');
    }
  }

  /// Confirms a planned occurrence: marks it accepted locally and notifies the server.
  Future<void> accept(FinancialEvent event, String dateYmd) async {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx == -1) return;
    final e = _events[idx];
    final accepted = List<String>.from(e.acceptedDates)..add(dateYmd);
    _events[idx] = _copyEvent(e, acceptedDates: accepted);
    _recalcDates();
    // Optimistic: show the confirmation instantly, then talk to the server.
    notifyListeners();
    await save();

    if (_apiClient.accessToken == null || e.serverId == null) return;
    try {
      // Accept the specific occurrence, not the whole chain: use the
      // per-date server occurrence id when available, otherwise fall back
      // to the chain's first occurrence id.
      final occurrenceId = e.occurrenceIds[dateYmd] ?? e.serverId!;
      await _apiClient.acceptCalendarEventV2(occurrenceId, e.chain ?? '', dateYmd);
    } catch (err) {
      debugPrint('accept calendar event error: $err');
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    _events = [];
    notifyListeners();
  }

  Future<void> toggleEnabled(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final old = _events[idx];
      _events[idx] = _copyEvent(old, enabled: !old.enabled);
      await save();
      await NotificationService().rescheduleAll();
      notifyListeners();
    }
  }

  void _recalcDates() {
    for (int i = 0; i < _events.length; i++) {
      final e = _events[i];
      final next = e.nextOccurrence();
      if (next != null) {
        final ymd = '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
        if (e.date != ymd) _events[i] = _copyEvent(e, date: ymd);
      }
    }
  }

  FinancialEvent _copyEvent(FinancialEvent e, {String? date, bool? enabled, List<String>? acceptedDates, Map<String, String>? occurrenceIds}) => FinancialEvent(
    id: e.id,
    title: e.title,
    date: date ?? e.date,
    amount: e.amount,
    type: e.type,
    comment: e.comment,
    isRecurring: e.isRecurring,
    dayOfMonth: e.dayOfMonth,
    specificDate: e.specificDate,
    enabled: enabled ?? e.enabled,
    accountId: e.accountId,
    toAccountId: e.toAccountId,
    categoryId: e.categoryId,
    tags: e.tags,
    repeatMode: e.repeatMode,
    serverId: e.serverId,
    chain: e.chain,
    weekDays: e.weekDays,
    dateStart: e.dateStart,
    dateEnd: e.dateEnd,
    repeatCount: e.repeatCount,
    time: e.time,
    acceptedDates: acceptedDates ?? e.acceptedDates,
    occurrenceIds: occurrenceIds ?? e.occurrenceIds,
  );

  FinancialEvent _copyWithServer(FinancialEvent e, {String? serverId, String? chain}) => FinancialEvent(
    id: e.id,
    title: e.title,
    date: e.date,
    amount: e.amount,
    type: e.type,
    comment: e.comment,
    isRecurring: e.isRecurring,
    dayOfMonth: e.dayOfMonth,
    specificDate: e.specificDate,
    enabled: e.enabled,
    accountId: e.accountId,
    toAccountId: e.toAccountId,
    categoryId: e.categoryId,
    tags: e.tags,
    repeatMode: e.repeatMode,
    serverId: serverId ?? e.serverId,
    chain: chain ?? e.chain,
    weekDays: e.weekDays,
    dateStart: e.dateStart,
    dateEnd: e.dateEnd,
    repeatCount: e.repeatCount,
    time: e.time,
    acceptedDates: e.acceptedDates,
    occurrenceIds: e.occurrenceIds,
  );

  String _parseDate(String? d) {
    if (d == null || d.isEmpty) return '';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }

  DateTime? _dateOnly(String? d) {
    final s = _parseDate(d);
    if (s.length < 10) return null;
    return DateTime.tryParse(s);
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _toCalendarBody(FinancialEvent e) {
    // We keep dates internally in ISO format (yyyy-mm-dd), which is exactly what
    // the server expects — so no russian-style (dd.mm.yyyy) conversion here.
    // For recurring events the anchor date is `dateStart`; one-time events have
    // no `dateStart`, so fall back to `date`.
    final date = e.dateStart ?? e.date;
    final recurring = e.repeatMode > 0;
    return <String, dynamic>{
      'account_id': e.accountId ?? '',
      'category_id': e.categoryId ?? '',
      // The calendar API defaults to RUB when the currency is missing, so a
      // planned payment on a USD account used to be stored as rubles.
      'currency_id': currencyIdResolver?.call(e.accountId) ?? '1',
      'amount': e.amount > 0 ? e.amount.toStringAsFixed(2) : '0',
      'date': date,
      'time': e.time ?? '00:00:00',
      'comment': e.comment ?? e.title,
      'type': e.type == 'income' ? '1' : e.type == 'transfer' ? '2' : '0',
      if (e.toAccountId != null) 'transfer_account_id': e.toAccountId,
      if (e.toAccountId != null) 'transfer_amount': e.amount > 0 ? e.amount.toStringAsFixed(2) : '0',
      'accepted': e.acceptedDates.isNotEmpty ? e.acceptedDates.length : 0,
      // Server `every_day` is the recurrence INTERVAL in days (1/7/30/90/365),
      // not the day-of-month.
      if (recurring) 'every_day': e.repeatMode,
      'date_start': e.dateStart ?? date,
      if (e.dateEnd != null && e.dateEnd!.isNotEmpty && e.dateEnd != '0000-00-00') 'date_end': e.dateEnd,
      // Server `repeat`: "1" = one-time, "0" = repeat until `date_end`,
      // otherwise it is the number of occurrences to generate.
      'repeat': e.repeatMode == 0
          ? '1'
          : (e.repeatCount != null && e.repeatCount! > 0 ? e.repeatCount.toString() : '0'),
      if (e.weekDays != null) 'week_days': e.weekDays,
    };
  }

  dynamic _extractId(Map<String, dynamic> resp) {
    if (resp case {'calendar': final List c} when c.isNotEmpty) return c.first['id'] ?? c.first['operation_id'];
    if (resp case {'response': {'response_data': final Map d}}) {
      final cal = d['calendar'];
      if (cal is List && cal.isNotEmpty) return cal.first['id'] ?? cal.first['operation_id'];
    }
    return resp['id'] ?? resp['operation_id'];
  }

  dynamic _extractChain(Map<String, dynamic> resp) {
    if (resp case {'calendar': final List c} when c.isNotEmpty) return c.first['chain_id'] ?? c.first['chain'];
    if (resp case {'response': {'response_data': final Map d}}) {
      final cal = d['calendar'];
      if (cal is List && cal.isNotEmpty) return cal.first['chain_id'] ?? cal.first['chain'];
    }
    return resp['chain_id'] ?? resp['chain'];
  }
}
