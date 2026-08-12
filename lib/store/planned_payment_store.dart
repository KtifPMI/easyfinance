import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/financial_event.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';

class PlannedPaymentStore extends ChangeNotifier {
  static const _key = 'easyfinance_planned_payments';
  final ApiClient _apiClient;
  List<FinancialEvent> _events = [];

  PlannedPaymentStore({required ApiClient apiClient}) : _apiClient = apiClient;

  List<FinancialEvent> get events => List.unmodifiable(_events);

  List<FinancialEvent> get upcomingEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = _events.where((e) {
      if (!e.enabled) return false;
      final next = e.nextOccurrence();
      return next != null && !next.isBefore(today);
    }).toList();
    result.sort((a, b) => (a.nextOccurrence() ?? today).compareTo(b.nextOccurrence() ?? today));
    return result;
  }

  List<FinancialEvent> get upcomingIncomes =>
      upcomingEvents.where((e) => e.type == 'income').toList();

  List<FinancialEvent> get upcomingExpenses =>
      upcomingEvents.where((e) => e.type == 'expense').toList();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _events = list.map((e) => FinancialEvent.fromJson(e as Map<String, dynamic>)).toList();
      _recalcDates();
    }
    notifyListeners();
  }

  /// Fetches planned payments from the API v2 and merges with local data.
  /// Server events are keyed by their operation id (serverId field).
  /// Local-only events (no serverId) are always preserved.
  Future<void> syncFromServer() async {
    if (_apiClient.accessToken == null) return;
    try {
      final data = await _apiClient.getCalendarEventsV2();
      final serverIds = <String>{};
      for (final raw in data) {
        final serverId = raw['id']?.toString();
        if (serverId == null) continue;
        serverIds.add(serverId);

        final existing = _events.where((e) => e.serverId == serverId).firstOrNull;
        final event = _fromCalendarJson(raw, serverId: serverId);
        if (existing == null) {
          _events.add(event);
        } else {
          final idx = _events.indexOf(existing);
          _events[idx] = event;
        }
      }

      // Remove only server-backed events that no longer exist on the server.
      _events.removeWhere((e) => e.serverId != null && !serverIds.contains(e.serverId));
      _recalcDates();
      await save();
      notifyListeners();
    } catch (e) {
      debugPrint('syncFromServer error: $e');
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_events.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<void> add(FinancialEvent event) async {
    if (_apiClient.accessToken != null) {
      try {
        final resp = await _apiClient.postCalendarEventV2(_toCalendarBody(event));
        final serverId = _extractId(resp)?.toString();
        final chain = _extractChain(resp)?.toString();
        if (serverId != null) {
          event = _copyWithServer(event, serverId: serverId, chain: chain);
        }
      } catch (e) {
        debugPrint('add calendar event error: $e');
      }
    }
    _events.add(event);
    _recalcDates();
    await save();
    await NotificationService().rescheduleAll();
    notifyListeners();
  }

  Future<void> update(String id, FinancialEvent updated) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    if (_apiClient.accessToken != null && updated.serverId != null) {
      try {
        await _apiClient.setCalendarEventV2(updated.serverId!, updated.chain ?? '', _toCalendarBody(updated));
      } catch (e) {
        debugPrint('update calendar event error: $e');
      }
    }

    _events[idx] = updated;
    _recalcDates();
    await save();
    await NotificationService().rescheduleAll();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final event = _events[idx];

    if (_apiClient.accessToken != null && event.serverId != null) {
      try {
        await _apiClient.deleteCalendarEventV2(event.serverId!, event.chain ?? '');
      } catch (e) {
        debugPrint('delete calendar event error: $e');
      }
    }

    _events.removeAt(idx);
    await save();
    await NotificationService().rescheduleAll();
    notifyListeners();
  }

  /// Confirms a planned occurrence: marks it accepted locally and notifies the server.
  Future<void> accept(FinancialEvent event, String dateYmd) async {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx == -1) return;
    final e = _events[idx];
    final accepted = List<String>.from(e.acceptedDates)..add(dateYmd);
    _events[idx] = _copyEvent(e, acceptedDates: accepted);

    if (_apiClient.accessToken != null && e.serverId != null) {
      try {
        await _apiClient.acceptCalendarEventV2(e.serverId!, e.chain ?? '', dateYmd);
      } catch (err) {
        debugPrint('accept calendar event error: $err');
      }
    }
    _recalcDates();
    await save();
    notifyListeners();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (int i = 0; i < _events.length; i++) {
      final e = _events[i];
      final next = e.nextOccurrence();
      if (next != null) {
        final ymd = '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
        if (e.date != ymd) _events[i] = _copyEvent(e, date: ymd);
      }
    }
  }

  FinancialEvent _copyEvent(FinancialEvent e, {String? date, bool? enabled, List<String>? acceptedDates}) => FinancialEvent(
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
    acceptedDates: acceptedDates ?? e.acceptedDates,
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
    acceptedDates: e.acceptedDates,
  );

  FinancialEvent _fromCalendarJson(Map<String, dynamic> json, {String? serverId}) {
    final acceptedRaw = json['accepted'];
    final accepted = acceptedRaw == 1 || acceptedRaw == '1' || acceptedRaw == true;
    final typeRaw = json['type']?.toString();
    final type = typeRaw == '1' ? 'income' : typeRaw == '2' ? 'transfer' : 'expense';
    final everyDay = int.tryParse(json['every_day']?.toString() ?? '0') ?? 0;
    final startStr = json['date_start']?.toString() ?? json['date']?.toString() ?? '';
    final startDay = _parseDay(startStr);
    return FinancialEvent(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      title: json['comment']?.toString() ?? '',
      date: _parseDate(json['date']?.toString()),
      amount: (double.tryParse(json['amount']?.toString() ?? '0') ?? 0).abs(),
      type: type,
      comment: json['comment']?.toString(),
      isRecurring: everyDay > 0,
      dayOfMonth: startDay,
      specificDate: null,
      enabled: true,
      accountId: json['account_id']?.toString(),
      toAccountId: json['transfer_account_id']?.toString(),
      categoryId: json['category_id']?.toString(),
      tags: json['tags']?.toString(),
      repeatMode: everyDay,
      serverId: serverId ?? json['id']?.toString(),
      chain: json['chain_id']?.toString(),
      weekDays: json['week_days']?.toString(),
      dateStart: json['date_start']?.toString(),
      dateEnd: json['date_end']?.toString(),
      acceptedDates: accepted ? [_parseDate(json['date']?.toString())] : const [],
    );
  }

  String _parseDate(String? d) {
    if (d == null || d.isEmpty) return '';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }

  int? _parseDay(String? d) {
    final s = _parseDate(d);
    if (s.length < 10) return null;
    return int.tryParse(s.substring(8, 10));
  }

  Map<String, dynamic> _toCalendarBody(FinancialEvent e) {
    String formatDate(String iso) {
      if (iso.length < 10) return iso;
      final p = iso.substring(0, 10).split('-');
      if (p.length == 3) return '${p[2]}.${p[1]}.${p[0]}';
      return iso;
    }

    final date = formatDate(e.date);
    return <String, dynamic>{
      'account_id': e.accountId ?? '',
      'category_id': e.categoryId ?? '',
      'amount': e.amount > 0 ? e.amount.toStringAsFixed(0) : '0',
      'date': date,
      'time': '00:00:00',
      'comment': e.comment ?? e.title,
      'type': e.type == 'income' ? '1' : e.type == 'transfer' ? '2' : '0',
      if (e.toAccountId != null) 'transfer_account_id': e.toAccountId,
      if (e.toAccountId != null) 'transfer_amount': e.amount > 0 ? e.amount.toStringAsFixed(0) : '0',
      'accepted': 0,
      if (e.dayOfMonth != null) 'every_day': e.dayOfMonth,
      'date_start': e.dateStart != null ? formatDate(e.dateStart!) : date,
      if (e.dateEnd != null && e.dateEnd!.isNotEmpty) 'date_end': formatDate(e.dateEnd!),
      'repeat': e.repeatMode,
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
