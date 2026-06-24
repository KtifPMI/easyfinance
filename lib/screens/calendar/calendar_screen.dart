import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/progress_bar.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final now = DateTime.now();
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final firstWeekday = DateTime(now.year, now.month, 1).weekday;
        final offset = firstWeekday - 1;

        return ScreenScaffold(
          title: 'Календарь',
          child: Column(
            children: [
              Text('${now.month}.${now.year}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((d) =>
                  SizedBox(width: 36, child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)))
                ).toList(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: [
                  for (int i = 0; i < offset; i++) const SizedBox(width: 36),
                  for (int d = 1; d <= daysInMonth; d++) ...[
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: d == now.day ? AppColors.primary : null,
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text('$d', style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: d == now.day ? Colors.white : AppColors.text,
                      ))),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              if (store.events.isEmpty)
                Text('Нет событий', style: TextStyle(color: AppColors.textSecondary))
              else
                ...store.events.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: e.type == 'income' ? AppColors.success.withOpacity(0.15) : AppColors.expense.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(e.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward, color: e.type == 'income' ? AppColors.success : AppColors.expense),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                              Text(formatDate(e.date), style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        if (e.amount != null)
                          Text(formatMoney(e.amount!), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: e.type == 'income' ? AppColors.success : AppColors.expense)),
                      ],
                    ),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }
}
