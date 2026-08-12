import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';
import '../../models/operation.dart';
import '../../models/financial_event.dart';
import '../../utils/format.dart';
import '../../utils/category_icons.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
  void _nextMonth() => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));

  @override
  Widget build(BuildContext context) {
    return Consumer2<FinanceStore, PlannedPaymentStore>(
      builder: (context, store, plannedStore, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
        final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
        final offset = firstWeekday - 1;
        final monthName = context.tr('month.long.${_currentMonth.month}');
        final monthLabel = '${monthName[0].toUpperCase()}${monthName.substring(1)} ${_currentMonth.year}';

        final opsByDate = <DateTime, List<Operation>>{};
        for (final op in store.operations) {
          if (op.isDeleted) continue;
          final d = DateTime.tryParse(op.date.substring(0, 10));
          if (d != null) {
            final key = DateTime(d.year, d.month, d.day);
            opsByDate.putIfAbsent(key, () => []);
            opsByDate[key]!.add(op);
          }
        }

        final plannedByDate = <DateTime, List<FinancialEvent>>{};
        for (final e in plannedStore.events) {
          if (!e.enabled) continue;
          final date = _occurrenceInMonth(e, _currentMonth);
          if (date != null) {
            final key = DateTime(date.year, date.month, date.day);
            plannedByDate.putIfAbsent(key, () => []);
            plannedByDate[key]!.add(e);
          }
        }

        final dayCells = <Widget>[];
        for (int i = 0; i < offset; i++) dayCells.add(const SizedBox.shrink());
        for (int d = 1; d <= daysInMonth; d++) {
          final date = DateTime(_currentMonth.year, _currentMonth.month, d);
          final isToday = date == today;
          final isSelected = date == _selectedDate;
          final hasOps = opsByDate.containsKey(date);
          final hasPlanned = plannedByDate.containsKey(date);
          dayCells.add(_dayCell(d, isToday, isSelected, hasOps, hasPlanned, () => setState(() => _selectedDate = date)));
        }

        final selectedOps = _selectedDate != null ? (opsByDate[_selectedDate] ?? <Operation>[]) : <Operation>[];
        final selectedPlanned = _selectedDate != null ? (plannedByDate[_selectedDate] ?? <FinancialEvent>[]) : <FinancialEvent>[];
        final upcomingPlanned = _selectedDate == null ? _allUpcoming(plannedStore) : <FinancialEvent>[];

        return ScreenScaffold(
          title: context.tr('calendar.title'),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.pushNamed(context, '/add-planned-payment', arguments: _selectedDate != null
                ? {'date': _selectedDate!.toIso8601String().substring(0, 10)}
                : null),
            child: const Icon(Icons.event),
          ),
          child: Column(
            children: [
              ScreenHint(hintId: 'calendar', text: context.tr('hints.calendar')),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                  Text(monthLabel, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [context.tr('calendar.mon'), context.tr('calendar.tue'), context.tr('calendar.wed'), context.tr('calendar.thu'), context.tr('calendar.fri'), context.tr('calendar.sat'), context.tr('calendar.sun')]
                    .map((d) => SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context)))))
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 4,
                crossAxisSpacing: 0,
                childAspectRatio: 1,
                children: dayCells,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _selectedDate != null
                    ? _buildDayEvents(context, store, selectedOps, selectedPlanned)
                    : _buildAllUpcoming(context, store, plannedStore, upcomingPlanned),
              ),
            ],
          ),
        );
      },
    );
  }

  List<FinancialEvent> _allUpcoming(PlannedPaymentStore plannedStore) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = plannedStore.events.where((e) {
      if (!e.enabled) return false;
      if (e.date.isEmpty) return false;
      final d = DateTime.tryParse(e.date);
      return d != null && !d.isBefore(today);
    }).toList();
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  Widget _buildAllUpcoming(BuildContext context, FinanceStore store, PlannedPaymentStore plannedStore, List<FinancialEvent> events) {
    if (events.isEmpty) {
      return Center(child: Text(context.tr('calendar.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context))));
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(context.tr('calendar.scheduled_payments'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryFor(context))),
        ),
        ...events.map((e) => _plannedPaymentTile(context, store, e)),
      ],
    );
  }

  Widget _buildDayEvents(BuildContext context, FinanceStore store, List<Operation> ops, List<FinancialEvent> planned) {
    return ListView(
      children: [
        Text(formatDateLong(_selectedDate!.toIso8601String()), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
        const SizedBox(height: 8),
        if (ops.isEmpty && planned.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 16), child: Text(context.tr('operations.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context)))),
        if (planned.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(context.tr('calendar.scheduled_payments'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryFor(context)))),
          ...planned.map((e) => _plannedPaymentTile(context, store, e)),
        ],
        if (ops.isNotEmpty) ...[
          if (planned.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(context.tr('calendar.operations'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryFor(context))),
            ),
          ...ops.map((op) => _operationTile(context, store, op)),
        ],
      ],
    );
  }

  Widget _plannedPaymentTile(BuildContext context, FinanceStore store, FinancialEvent e) {
    final cat = e.categoryId != null ? store.getCategory(e.categoryId) : null;
    final iconData = cat != null ? categoryIconFor(cat, allCategories: store.categories) : (e.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward);
    final iconColor = e.type == 'income' ? AppColors.success : AppColors.expense;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                  Text(formatDate(e.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(store.fmt(e.amount), maxLines: 1, softWrap: false, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: iconColor)),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: AppColors.textSecondaryFor(context)),
              onSelected: (v) {
                if (v == 'edit') {
                  Navigator.pushNamed(context, '/add-planned-payment', arguments: e);
                } else if (v == 'confirm') {
                  _confirmCreateOp(context, e, store);
                } else if (v == 'delete') {
                  _confirmDeletePlanned(context, e, store);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(context.tr('calendar.edit_payment'))),
                PopupMenuItem(value: 'confirm', child: Text(context.tr('calendar.confirm_operation'), style: TextStyle(color: AppColors.primary))),
                PopupMenuItem(value: 'delete', child: Text(context.tr('calendar.delete_payment'), style: TextStyle(color: AppColors.expense))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _operationTile(BuildContext context, FinanceStore store, Operation op) {
    final cat = store.getCategory(op.categoryId);
    final iconData = cat != null ? categoryIconFor(cat, allCategories: store.categories) : (op.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward);
    final iconColor = op.type == 'income' ? AppColors.success : AppColors.expense;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/operation-detail', arguments: {'operationId': op.id}),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(op.comment ?? cat?.name ?? context.tr('operations.no_category'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                    Text(store.getAccount(op.accountId)?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(store.fmt(op.amount, fromCurrency: op.currency), maxLines: 1, softWrap: false, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: op.type == 'income' ? AppColors.success : AppColors.expense)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletePlanned(BuildContext context, FinancialEvent e, FinanceStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('calendar.delete_payment')),
        content: Text('${e.title} — ${store.fmt(e.amount)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('calendar.cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PlannedPaymentStore>().remove(e.id);
            },
            child: Text(context.tr('calendar.delete'), style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }

  void _confirmPendingOp(BuildContext context, FinanceStore store, Operation op) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('calendar.confirm_operation')),
        content: Text('${store.fmt(op.amount)} — ${op.comment ?? ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('calendar.cancel'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await store.updateOperation(op.copyWith(isPending: false));
            },
            child: Text(context.tr('calendar.confirm_operation'), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOp(BuildContext context, FinanceStore store, Operation op) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('calendar.delete_payment')),
        content: Text('${op.comment ?? ''} — ${store.fmt(op.amount)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('calendar.cancel'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await store.deleteOperation(op.id);
              if (!context.mounted) return;
              if (store.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!), backgroundColor: AppColors.danger));
              }
            },
            child: Text(context.tr('calendar.delete'), style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }

  void _confirmCreateOp(BuildContext context, FinancialEvent e, FinanceStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.title),
        content: Text('${store.fmt(e.amount)}\n${context.tr('calendar.confirm_create_op')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('calendar.cancel'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final now = DateTime.now();
              final op = Operation(
                id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
                type: e.type,
                amount: e.amount,
                date: e.date.isNotEmpty ? e.date : now.toIso8601String(),
                accountId: e.accountId ?? store.accounts.firstOrNull?.id ?? '',
                toAccountId: e.toAccountId,
                categoryId: e.categoryId,
                comment: e.comment ?? e.title,
                tags: e.tags,
                isPending: false,
              );
              await store.addOperation(op);
            },
            child: Text(context.tr('calendar.create_operation'), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  DateTime? _occurrenceInMonth(FinancialEvent e, DateTime month) {
    if (e.isRecurring && e.dayOfMonth != null) {
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      final day = e.dayOfMonth! > daysInMonth ? daysInMonth : e.dayOfMonth!;
      return DateTime(month.year, month.month, day);
    }
    if (e.specificDate != null) {
      final d = DateTime.tryParse(e.specificDate!);
      if (d != null && d.year == month.year && d.month == month.month) return d;
    }
    if (e.date.isNotEmpty) {
      final d = DateTime.tryParse(e.date);
      if (d != null && d.year == month.year && d.month == month.month) return d;
    }
    return null;
  }

  Widget _dayCell(int day, bool isToday, bool isSelected, bool hasOps, bool hasPlanned, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : null,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isToday ? AppColors.primary : null,
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text('$day', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isToday ? Colors.white : AppColors.textFor(context)))),
              ),
              if (hasOps || hasPlanned)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasOps)
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    if (hasOps && hasPlanned)
                      const SizedBox(width: 3),
                    if (hasPlanned)
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.warning, shape: BoxShape.circle)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
