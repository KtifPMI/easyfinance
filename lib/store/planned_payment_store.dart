import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/financial_event.dart';

class PlannedPaymentStore extends ChangeNotifier {
  static const _key = 'easyfinance_planned_payments';
  List<FinancialEvent> _events = [];

  List<FinancialEvent> get events => List.unmodifiable(_events);

  List<FinancialEvent> get upcomingEvents {
    final now = DateTime.now();
    final result = _events.where((e) {
      if (!e.enabled) return false;
      if (e.date.isEmpty) return false;
      final d = DateTime.tryParse(e.date);
      return d != null && d.isAfter(now);
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

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_events.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<void> add(FinancialEvent event) async {
    _events.add(event);
    _recalcDates();
    await save();
    notifyListeners();
  }

  Future<void> update(String id, FinancialEvent updated) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _events[idx] = updated;
      _recalcDates();
      await save();
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    _events.removeWhere((e) => e.id == id);
    await save();
    notifyListeners();
  }

  Future<void> toggleEnabled(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final old = _events[idx];
      _events[idx] = FinancialEvent(
        id: old.id,
        title: old.title,
        date: old.date,
        amount: old.amount,
        type: old.type,
        comment: old.comment,
        isRecurring: old.isRecurring,
        dayOfMonth: old.dayOfMonth,
        specificDate: old.specificDate,
        enabled: !old.enabled,
      );
      await save();
      notifyListeners();
    }
  }

  void _recalcDates() {
    final now = DateTime.now();
    for (int i = 0; i < _events.length; i++) {
      final e = _events[i];
      if (e.isRecurring && e.dayOfMonth != null) {
        var next = DateTime(now.year, now.month, e.dayOfMonth!);
        if (next.isBefore(DateTime(now.year, now.month, now.day))) {
          next = DateTime(now.year, now.month + 1, e.dayOfMonth!);
        }
        _events[i] = FinancialEvent(
          id: e.id,
          title: e.title,
          date: next.toIso8601String().substring(0, 10),
          amount: e.amount,
          type: e.type,
          comment: e.comment,
          isRecurring: e.isRecurring,
          dayOfMonth: e.dayOfMonth,
          specificDate: e.specificDate,
          enabled: e.enabled,
        );
      } else if (e.specificDate != null) {
        _events[i] = FinancialEvent(
          id: e.id,
          title: e.title,
          date: e.specificDate!,
          amount: e.amount,
          type: e.type,
          comment: e.comment,
          isRecurring: e.isRecurring,
          dayOfMonth: e.dayOfMonth,
          specificDate: e.specificDate,
          enabled: e.enabled,
        );
      }
    }
  }
}
