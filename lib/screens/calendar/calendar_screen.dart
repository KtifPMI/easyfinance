import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/common/screen_hint.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';
import '../../models/operation.dart';
import '../../models/financial_event.dart';
import '../../utils/format.dart';
import '../../utils/category_icons.dart';
import '../../utils/planned_event_title.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlannedPaymentStore>().syncFromServer();
    });
  }

  void _prevMonth() => setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
        if (_selectedDate != null) _selectedDate = _shiftDay(_selectedDate!, _currentMonth);
      });

  Widget _calendarLegend(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(context.tr('calendar.legend_planned'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(context.tr('calendar.legend_overdue'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.transfer, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(context.tr('calendar.legend_confirmed'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
          ],
        ),
      ],
    );
  }
  void _nextMonth() => setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
        if (_selectedDate != null) _selectedDate = _shiftDay(_selectedDate!, _currentMonth);
      });

  DateTime _shiftDay(DateTime date, DateTime month) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final d = date.day > days ? days : date.day;
    return DateTime(month.year, month.month, d);
  }

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
          for (final occ in e.occurrencesInMonth(_currentMonth)) {
            final key = DateTime(occ.year, occ.month, occ.day);
            plannedByDate.putIfAbsent(key, () => []);
            plannedByDate[key]!.add(e);
          }
        }

        final dayCells = <Widget>[];
        for (int i = 0; i < offset; i++) {
          dayCells.add(const SizedBox.shrink());
        }
        for (int d = 1; d <= daysInMonth; d++) {
          final date = DateTime(_currentMonth.year, _currentMonth.month, d);
          final isToday = date == today;
          final isSelected = date == _selectedDate;
          final hasOps = opsByDate.containsKey(date);
          final planned = plannedByDate[date];
          Color? plannedColor;
          if (planned != null && planned.isNotEmpty) {
            final ymd = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final completed = planned.any((e) => e.isAcceptedOn(ymd));
            final todayOnly = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            if (completed) {
              plannedColor = AppColors.transfer;
            } else if (date.isBefore(todayOnly)) {
              plannedColor = AppColors.danger;
            } else {
              plannedColor = Colors.grey;
            }
          }
          dayCells.add(_dayCell(d, isToday, isSelected, hasOps, plannedColor, () => setState(() => _selectedDate = date)));
        }

        final selectedOps = _selectedDate != null ? (opsByDate[_selectedDate] ?? <Operation>[]) : <Operation>[];
        final selectedPlanned = _selectedDate != null ? (plannedByDate[_selectedDate] ?? <FinancialEvent>[]) : <FinancialEvent>[];
        final monthPlanned = _selectedDate == null ? _monthPlannedOccurrences(plannedStore) : <Map<String, dynamic>>[];

        return ScreenScaffold(
          title: context.tr('calendar.title'),
          scrollable: false,
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.pushNamed(context, '/add-planned-payment', arguments: _selectedDate != null
                ? {'date': _selectedDate!.toIso8601String().substring(0, 10)}
                : null),
            child: const Icon(Icons.event),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                _calendarLegend(context),
                const SizedBox(height: 8),
                Expanded(
                  child: _selectedDate != null
                      ? _buildDayEvents(context, store, selectedOps, selectedPlanned)
                      : _buildMonthCombinedView(context, store, plannedStore, monthPlanned),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _monthPlannedOccurrences(PlannedPaymentStore plannedStore) {
    final list = <Map<String, dynamic>>[];
    for (final e in plannedStore.events) {
      if (!e.enabled) continue;
      for (final occ in e.occurrencesInMonth(_currentMonth)) {
        list.add({'event': e, 'date': occ});
      }
    }
    list.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return list;
  }

  Widget _buildMonthCombinedView(BuildContext context, FinanceStore store, PlannedPaymentStore plannedStore, List<Map<String, dynamic>> plannedItems) {
    final monthOps = store.operations
        .where((o) => !o.isDeleted && store.isInMonth(o.date, _currentMonth))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (plannedItems.isEmpty && monthOps.isEmpty) {
      return Center(child: Text(context.tr('calendar.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context))));
    }
    return ListView(
      children: [
        if (plannedItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('calendar.planned_operations'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryFor(context))),
          ),
          ...plannedItems.map((m) => _plannedPaymentTile(context, store, m['event'] as FinancialEvent, occurrenceDate: m['date'] as DateTime)),
        ],
        if (monthOps.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text('calendar.actual_operations'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryFor(context))),
          ),
          ...monthOps.map((op) => _operationTile(context, store, op)),
        ],
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
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('calendar.planned_operations'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryFor(context)))),
          ...planned.map((e) => _plannedPaymentTile(context, store, e, occurrenceDate: _selectedDate)),
        ],
        if (ops.isNotEmpty) ...[
              if (planned.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text('calendar.actual_operations'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondaryFor(context))),
                ),
          ...ops.map((op) => _operationTile(context, store, op)),
        ],
      ],
    );
  }

  Widget _plannedPaymentTile(BuildContext context, FinanceStore store, FinancialEvent e, {DateTime? occurrenceDate}) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final ymd = occurrenceDate != null ? '${occurrenceDate.year}-${occurrenceDate.month.toString().padLeft(2, '0')}-${occurrenceDate.day.toString().padLeft(2, '0')}' : e.date;
    final accepted = e.isAcceptedOn(ymd);
    final isOverdue = occurrenceDate != null && occurrenceDate.isBefore(today) && !accepted;

    final cat = e.categoryId != null ? store.getCategory(e.categoryId) : null;
    final iconData = cat != null ? categoryIconFor(cat, allCategories: store.categories) : (e.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward);
    final iconColor = isOverdue ? AppColors.expense : (e.type == 'income' ? AppColors.success : AppColors.expense);
    final isCompleted = accepted;
    final displayDate = occurrenceDate
        ?? (e.dateStart != null ? DateTime.tryParse(e.dateStart!) : null)
        ?? (e.date.isNotEmpty ? DateTime.tryParse(e.date) : null);
    final displayDateStr = displayDate != null
        ? '${displayDate.year}-${displayDate.month.toString().padLeft(2, '0')}-${displayDate.day.toString().padLeft(2, '0')}'
        : e.date;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showPlannedActionDialog(context, store, e, occurrenceDate),
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
                          Text(plannedEventTitle(e, store), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                          Row(
                            children: [
                              Text(formatDate(displayDateStr), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                              if (isCompleted) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text('calendar.confirmed'.tr(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                                ),
                              ] else if (isOverdue) ...[
                                const SizedBox(width: 6),
                                Text('• ${context.tr('calendar.overdue')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.expense)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(store.fmt(e.amount), maxLines: 1, softWrap: false, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: iconColor)),
                  ],
                ),
              ),
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
        content: Text('${plannedEventTitle(e, store)} — ${store.fmt(e.amount)}'),
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

  void _showPlannedActionDialog(BuildContext context, FinanceStore store, FinancialEvent e, [DateTime? occurrenceDate]) {
    final ymd = occurrenceDate != null
        ? '${occurrenceDate.year}-${occurrenceDate.month.toString().padLeft(2, '0')}-${occurrenceDate.day.toString().padLeft(2, '0')}'
        : e.date;
    final accepted = e.isAcceptedOn(ymd);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plannedEventTitle(e, store)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(store.fmt(e.amount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(formatDate(e.date), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/add-planned-payment', arguments: e);
            },
            child: Text(context.tr('calendar.edit_payment')),
          ),
          if (!accepted)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _createPlannedOperation(context, e, store, occurrenceDate);
              },
              child: Text(context.tr('calendar.confirm_operation'), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('calendar.confirmed'.tr(), style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
            ),
          TextButton(
            onPressed: () => _confirmDeletePlanned(context, e, store),
            child: Text(context.tr('calendar.delete_payment'), style: TextStyle(color: AppColors.expense)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('calendar.cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlannedOperation(BuildContext context, FinancialEvent e, FinanceStore store, [DateTime? occurrenceDate]) async {
    final planned = context.read<PlannedPaymentStore>();
    if (e.serverId == null) {
      // Local-only planned payment (never synced): create a real operation
      // directly. Server-backed ones are handled by `accept`, which marks the
      // existing planned operation as accepted — creating it here too would
      // duplicate it.
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
    } else {
      final ymd = occurrenceDate != null
          ? '${occurrenceDate.year}-${occurrenceDate.month.toString().padLeft(2, '0')}-${occurrenceDate.day.toString().padLeft(2, '0')}'
          : e.date;
      await planned.accept(e, ymd);
      // Re-sync from server so the accepted occurrence matches the
      // authoritative per-operation state (a chain is collapsed into a single
      // local event, but acceptance is tracked per server operation id).
      if (context.mounted) await planned.syncFromServer();
    }
    if (context.mounted) await store.reloadOperations();
  }

  Widget _dayCell(int day, bool isToday, bool isSelected, bool hasOps, Color? plannedColor, VoidCallback onTap) {
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
              if (hasOps || plannedColor != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasOps)
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    if (hasOps && plannedColor != null)
                      const SizedBox(width: 3),
                    if (plannedColor != null)
                      Container(width: 4, height: 4, decoration: BoxDecoration(color: plannedColor, shape: BoxShape.circle)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
