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
      if (e.date.isEmpty) return false;
      final d = DateTime.tryParse(e.date);
      return d != null && !d.isBefore(today);
    }).toList();
    result.sort((a, b) => a.date.compareTo(b.date));
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

  /// Fetches planned payments from the server and merges with local data.
  /// Server events are keyed by their operation id (serverId field).
  Future<void> syncFromServer() async {
    if (_apiClient.webSessionId == null) return;
    try {
      final data = await _apiClient.getCalendarEvents();
      final calendar = data['calendar'] as Map<String, dynamic>?;
      if (calendar == null) return;

      final serverIds = <String>{};
      for (final entry in calendar.entries) {
        final raw = entry.value as Map<String, dynamic>?;
        if (raw == null) continue;
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

      // Remove local events that no longer exist on server
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
    if (_apiClient.webSessionId != null) {
      try {
        final resp = await _apiClient.postCalendarEvent(_toCalendarForm(event));
        final calendar = resp['calendar'] as Map<String, dynamic>?;
        if (calendar != null) {
          final entry = calendar.values.first as Map<String, dynamic>?;
          if (entry != null) {
            final serverId = entry['id']?.toString();
            final chain = entry['chain']?.toString();
            event = _copyWithServer(event, serverId: serverId, chain: chain);
          }
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

    if (_apiClient.webSessionId != null && updated.serverId != null) {
      try {
        await _apiClient.postCalendarEvent(_toCalendarForm(updated));
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

    if (_apiClient.webSessionId != null && event.serverId != null) {
      try {
        await _apiClient.deleteCalendarEvent(event.serverId!, event.chain ?? '');
      } catch (e) {
        debugPrint('delete calendar event error: $e');
      }
    }

    _events.removeAt(idx);
    await save();
    await NotificationService().rescheduleAll();
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
    for (int i = 0; i < _events.length; i++) {
      final e = _events[i];
      if (e.isRecurring && e.dayOfMonth != null) {
        var next = _dateForDay(now.year, now.month, e.dayOfMonth!);
        if (next.isBefore(DateTime(now.year, now.month, now.day))) {
          next = _dateForDay(now.year, now.month + 1, e.dayOfMonth!);
        }
        _events[i] = _copyEvent(e, date: next.toIso8601String().substring(0, 10));
      } else if (e.specificDate != null && e.specificDate!.isNotEmpty) {
        _events[i] = _copyEvent(e, date: e.specificDate!);
      }
    }
  }

  DateTime _dateForDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  FinancialEvent _copyEvent(FinancialEvent e, {String? date, bool? enabled}) => FinancialEvent(
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
    categoryId: e.categoryId,
    tags: e.tags,
    repeatMode: e.repeatMode,
    serverId: e.serverId,
    chain: e.chain,
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
    categoryId: e.categoryId,
    tags: e.tags,
    repeatMode: e.repeatMode,
    serverId: serverId ?? e.serverId,
    chain: chain ?? e.chain,
  );

  FinancialEvent _fromCalendarJson(Map<String, dynamic> json, {String? serverId}) {
    return FinancialEvent(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      title: json['comment']?.toString() ?? '',
      date: _parseDotDate(json['date']?.toString()),
      amount: (double.tryParse(json['money']?.toString() ?? '0') ?? 0).abs(),
      type: json['type'] == '0' ? 'expense' : 'income',
      comment: json['comment']?.toString(),
      tags: json['tags']?.toString(),
      repeatMode: int.tryParse(json['every']?.toString() ?? '0') ?? 0,
      isRecurring: (int.tryParse(json['every']?.toString() ?? '0') ?? 0) > 0,
      dayOfMonth: null,
      accountId: json['account_id']?.toString(),
      categoryId: json['cat_id']?.toString(),
      enabled: true,
      serverId: serverId ?? json['id']?.toString(),
      chain: json['chain']?.toString(),
    );
  }

  String _parseDotDate(String? d) {
    if (d == null || d.isEmpty) return '';
    final parts = d.split('.');
    if (parts.length == 3) return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    return d;
  }

  Map<String, String> _toCalendarForm(FinancialEvent e) {
    String formatDotDate(String iso) {
      if (iso.length < 10) return iso;
      final p = iso.substring(0, 10).split('-');
      if (p.length == 3) return '${p[2]}.${p[1]}.${p[0]}';
      return iso;
    }

    final date = formatDotDate(e.date);
    return <String, String>{
      'responseMode': 'json',
      if (e.serverId != null) 'id': e.serverId!,
      if (e.chain != null && e.chain!.isNotEmpty) 'chain': e.chain! else 'chain': '',
      'type': e.type == 'income' ? '1' : '0',
      'account': e.accountId ?? '',
      'category': e.categoryId ?? '',
      'amount': e.amount > 0 ? e.amount.toStringAsFixed(0) : '0',
      'date': date,
      'setTime': '0',
      'time': '09:00',
      'comment': e.comment ?? '',
      'tags': e.tags ?? '',
      'every': e.repeatMode.toString(),
      'repeat': e.repeatMode > 0 ? '1' : '0',
      'week': '0000000',
      'last': '00.00.0000',
      'toAccount': '',
      'currency': '0',
      'convert': '0',
      'target': '',
      'close': '0',
      'mailEnabled': 'false',
      'mailDaysBefore': '0',
      'mailHour': '11',
      'mailMinutes': '0',
      'smsEnabled': 'false',
      'smsDaysBefore': '0',
      'smsHour': '11',
      'smsMinutes': '0',
    };
  }
}
