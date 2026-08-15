import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import '../models/financial_event.dart';
import '../store/finance_store.dart';
import '../utils/format.dart';

/// Resolves a human-readable title for a planned payment.
/// Falls back: explicit title -> comment -> category name -> account name -> default.
String plannedEventTitle(FinancialEvent e, FinanceStore store) {
  if (e.title.isNotEmpty) return e.title;
  if (e.comment?.isNotEmpty == true) return e.comment!;
  final cat = e.categoryId != null ? store.getCategory(e.categoryId) : null;
  if (cat != null) return cat.name;
  final acc = e.accountId != null ? store.getAccount(e.accountId) : null;
  if (acc != null) return acc.name;
  return 'Запланированный платёж';
}

/// Human-readable recurrence description for a planned payment, e.g.
/// "Каждую неделю с 15 авг (6 раз)" or "Каждый месяц с 15 авг до 15 фев".
String recurrenceSummary(BuildContext context, FinancialEvent e) {
  if (!e.isRepeating) {
    return formatDate(e.date);
  }
  final periodKey = <int, String>{
    1: 'planned_payments.repeat_daily',
    7: 'planned_payments.repeat_weekly',
    30: 'planned_payments.repeat_monthly',
    90: 'planned_payments.repeat_quarterly',
    365: 'planned_payments.repeat_yearly',
  }[e.repeatMode] ?? 'planned_payments.repeat_daily';
  final period = context.tr(periodKey);
  final startStr = formatDate(e.dateStart ?? e.date);
  final count = e.repeatCount;
  if (count != null && count > 0) {
    return '$period ${context.tr('planned_payments.rec_from')} $startStr (${count} ${context.tr('rec_settings.times')})';
  }
  if (e.dateEnd != null && e.dateEnd!.isNotEmpty && e.dateEnd != '0000-00-00') {
    return '$period ${context.tr('planned_payments.rec_from')} $startStr ${context.tr('planned_payments.rec_until')} ${formatDate(e.dateEnd!)}';
  }
  return '$period ${context.tr('planned_payments.rec_from')} $startStr';
}
