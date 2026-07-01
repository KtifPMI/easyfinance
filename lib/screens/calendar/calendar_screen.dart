import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../models/operation.dart';
import '../../utils/format.dart';

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
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
  void _nextMonth() => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
        final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
        final offset = firstWeekday - 1;
        final locale = Intl.defaultLocale ?? 'ru';
        final monthLabel = DateFormat.yMMMM(locale).format(_currentMonth);

        final opsByDate = <DateTime, List<Operation>>{};
        for (final op in store.operations) {
          final d = DateTime.tryParse(op.date.substring(0, 10));
          if (d != null) {
            final key = DateTime(d.year, d.month, d.day);
            opsByDate.putIfAbsent(key, () => []);
            opsByDate[key]!.add(op);
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
          dayCells.add(_dayCell(d, isToday, isSelected, hasOps, () {
            setState(() => _selectedDate = date);
          }));
        }

        final selectedOps = opsByDate[_selectedDate] ?? <Operation>[];

        return ScreenScaffold(
          title: context.tr('calendar.title'),
          child: Column(
            children: [
              ScreenHint(hintId: 'calendar', text: 'Нажмите на день, чтобы увидеть все операции за эту дату. Можно листать месяцы стрелками.'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                  Text(monthLabel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [context.tr('calendar.mon'), context.tr('calendar.tue'), context.tr('calendar.wed'), context.tr('calendar.thu'), context.tr('calendar.fri'), context.tr('calendar.sat'), context.tr('calendar.sun')]
                    .map((d) => SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))))
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
              const SizedBox(height: 16),
              if (_selectedDate != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDateLong(_selectedDate!.toIso8601String()), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.tr('operations.add')),
                      onPressed: () => Navigator.pushNamed(context, '/add-operation', arguments: {'presetDate': _selectedDate!.toIso8601String().substring(0, 10)}),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (selectedOps.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  child: Text(context.tr('operations.empty'), style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                ...selectedOps.map((op) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(context, '/operation-detail', arguments: {'operationId': op.id}),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: (op.type == 'income' ? AppColors.success : AppColors.expense).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(op.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward, size: 20, color: op.type == 'income' ? AppColors.success : AppColors.expense),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(op.comment ?? store.getCategory(op.categoryId)?.name ?? context.tr('operations.no_category'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                                Text(store.getAccount(op.accountId)?.name ?? '', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Text(formatMoney(op.amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: op.type == 'income' ? AppColors.success : AppColors.expense)),
                        ],
                      ),
                    ),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _dayCell(int day, bool isToday, bool isSelected, bool hasOps, VoidCallback onTap) {
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
                child: Center(child: Text('$day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isToday ? Colors.white : AppColors.text))),
              ),
              if (hasOps)
                Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            ],
          ),
        ),
      ),
    );
  }
}
