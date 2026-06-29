import 'package:flutter/widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/operation.dart';

String formatMoney(double amount, {String currency = 'RUB'}) {
  final symbols = {'RUB': '₽', 'USD': '\$', 'EUR': '€'};
  final symbol = symbols[currency] ?? currency;
  final sign = amount < 0 ? '-' : '';
  final abs = amount.abs();
  final locale = Intl.defaultLocale ?? 'ru';
  final formatted = NumberFormat('#,###', locale).format(abs);
  return '$sign$formatted $symbol';
}

String formatSignedMoney(double amount, {String currency = 'RUB'}) {
  final sign = amount > 0 ? '+' : '';
  return '$sign${formatMoney(amount, currency: currency)}';
}

String formatDate(String iso) {
  final d = DateTime.parse(iso);
  final locale = Intl.defaultLocale ?? 'ru';
  final month = DateFormat.MMM(locale).format(d);
  return '${d.day.toString().padLeft(2, '0')} $month';
}

String formatDateLong(String iso) {
  final d = DateTime.parse(iso);
  final locale = Intl.defaultLocale ?? 'ru';
  return DateFormat.yMMMd(locale).format(d);
}

String formatDayLabel(String iso, BuildContext context) {
  final date = DateTime.parse(iso);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);

  if (d == today) return context.tr('date.today');
  if (d == yesterday) return context.tr('date.yesterday');
  if (d == tomorrow) return context.tr('date.tomorrow');
  return formatDateLong(iso);
}

List<MapEntry<String, List<Operation>>> groupByDay(List<Operation> items) {
  final map = <String, List<Operation>>{};
  for (final item in items) {
    final key = item.date.substring(0, 10);
    map.putIfAbsent(key, () => []);
    map[key]!.add(item);
  }
  final entries = map.entries.toList();
  entries.sort((a, b) => b.key.compareTo(a.key));
  return entries;
}
