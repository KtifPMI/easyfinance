import 'package:intl/intl.dart';
import '../models/operation.dart';

String formatMoney(double amount, {String currency = 'RUB'}) {
  final symbols = {'RUB': '₽', 'USD': '\$', 'EUR': '€'};
  final symbol = symbols[currency] ?? currency;
  final sign = amount < 0 ? '-' : '';
  final abs = amount.abs();
  final formatted = NumberFormat('#,###', 'ru-RU').format(abs);
  return '$sign$formatted $symbol';
}

String formatSignedMoney(double amount, {String currency = 'RUB'}) {
  final sign = amount > 0 ? '+' : '';
  return '$sign${formatMoney(amount, currency: currency)}';
}

String formatDate(String iso) {
  final d = DateTime.parse(iso);
  final months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]}';
}

String formatDateLong(String iso) {
  final d = DateTime.parse(iso);
  final months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String formatDayLabel(String iso) {
  final date = DateTime.parse(iso);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);

  if (d == today) return 'Сегодня';
  if (d == yesterday) return 'Вчера';
  if (d == tomorrow) return 'Завтра';
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
