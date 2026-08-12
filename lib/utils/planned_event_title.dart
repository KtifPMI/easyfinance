import '../models/financial_event.dart';
import '../store/finance_store.dart';

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
