import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_chip.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/operations/operation_list_item.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

class OperationsListScreen extends StatefulWidget {
  const OperationsListScreen({super.key});

  @override
  State<OperationsListScreen> createState() => _OperationsListScreenState();
}

class _OperationsListScreenState extends State<OperationsListScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        var ops = store.operations.toList();
        if (_filter == 'income') ops = ops.where((o) => o.type == 'income').toList();
        if (_filter == 'expense') ops = ops.where((o) => o.type == 'expense').toList();

        final grouped = groupByDay(ops);

        return ScreenScaffold(
          title: context.tr('operations.title'),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.pushNamed(context, '/add-operation'),
            child: const Icon(Icons.add),
          ),
          onRefresh: () => store.fetchAllData(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHint(hintId: 'operations', text: 'Список всех операций — доходов, расходов и переводов. Используйте фильтр сверху, чтобы посмотреть только расходы или доходы.'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppChip(label: context.tr('operations.all'), active: _filter == 'all', onPressed: () => setState(() => _filter = 'all')),
                    AppChip(label: context.tr('operations.income'), active: _filter == 'income', onPressed: () => setState(() => _filter = 'income')),
                    AppChip(label: context.tr('operations.expense'), active: _filter == 'expense', onPressed: () => setState(() => _filter = 'expense')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (grouped.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(context.tr('operations.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context)))))
              else
                ...grouped.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(formatDayLabel(entry.key, context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: entry.value.map((op) {
                          final cat = store.getCategory(op.categoryId);
                          final acc = store.getAccount(op.accountId);
                          final toAcc = store.getAccount(op.toAccountId);
                          final IconData iconData;
                          final Color iconColor;
                          if (op.type == 'transfer') {
                            iconData = Icons.swap_horiz;
                            iconColor = AppColors.transfer;
                          } else if (cat != null && cat.name.toLowerCase().contains('инвестицион')) {
                            iconData = Icons.track_changes;
                            iconColor = AppColors.warning;
                          } else if (op.type == 'expense') {
                            iconData = Icons.trending_down;
                            iconColor = AppColors.expense;
                          } else {
                            iconData = Icons.trending_up;
                            iconColor = AppColors.success;
                          }
                          final title = op.type == 'transfer'
                              ? '${acc?.name ?? ''} → ${toAcc?.name ?? ''}'
                              : cat?.name ?? context.tr('operations.no_category');

                          return OperationListItem(
                            title: title,
                            subtitle: op.comment ?? acc?.name ?? '',
                            tags: store.getTagsForOperation(op),
                            amount: op.amount,
                            type: op.type,
                            icon: iconData,
                            iconColor: iconColor,
                            onTap: () => Navigator.pushNamed(context, '/operation-detail', arguments: {'operationId': op.id}),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                )),
            ],
          ),
        );
      },
    );
  }
}
