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
  String _periodFilter = 'all';
  String? _accountIdFilter;

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        var ops = store.operations.toList();
        if (_filter == 'income') ops = ops.where((o) => o.type == 'income').toList();
        if (_filter == 'expense') ops = ops.where((o) => o.type == 'expense').toList();
        if (_accountIdFilter != null) ops = ops.where((o) => o.accountId == _accountIdFilter || o.toAccountId == _accountIdFilter).toList();

        if (_periodFilter != 'all') {
          final now = DateTime.now();
          DateTime? from;
          switch (_periodFilter) {
            case 'day': from = DateTime(now.year, now.month, now.day); break;
            case 'week': from = now.subtract(Duration(days: now.weekday - 1)); from = DateTime(from.year, from.month, from.day); break;
            case 'month': from = DateTime(now.year, now.month, 1); break;
          }
          if (from != null) {
            ops = ops.where((o) {
              final d = DateTime.tryParse(o.date);
              return d != null && d.isAfter(from!.subtract(const Duration(seconds: 1)));
            }).toList();
          }
        }

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
              Row(
                children: [
                  _quickAction(context, Icons.add_circle_outline, context.tr('quick_actions.income'), AppColors.success, () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'income'})),
                  _quickAction(context, Icons.remove_circle_outline, context.tr('quick_actions.expense'), AppColors.expense, () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'expense'})),
                  _quickAction(context, Icons.swap_horiz, context.tr('quick_actions.transfer'), AppColors.transfer, () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'transfer'})),
                  _quickAction(context, Icons.document_scanner, 'Чек', AppColors.accent, () => Navigator.pushNamed(context, '/scan-receipt')),
                ],
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppChip(label: context.tr('filters.all_time'), active: _periodFilter == 'all', onPressed: () => setState(() => _periodFilter = 'all')),
                    AppChip(label: context.tr('filters.day'), active: _periodFilter == 'day', onPressed: () => setState(() => _periodFilter = 'day')),
                    AppChip(label: context.tr('filters.week'), active: _periodFilter == 'week', onPressed: () => setState(() => _periodFilter = 'week')),
                    AppChip(label: context.tr('filters.month'), active: _periodFilter == 'month', onPressed: () => setState(() => _periodFilter = 'month')),
                  ],
                ),
              ),
              if (store.accounts.length > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(context.tr('filters.all_accounts'), style: const TextStyle(fontSize: 12)),
                          selected: _accountIdFilter == null,
                          onSelected: (_) => setState(() => _accountIdFilter = null),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          side: BorderSide.none,
                        ),
                      ),
                      ...store.accounts.map((a) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(a.name, style: const TextStyle(fontSize: 12)),
                          selected: _accountIdFilter == a.id,
                          onSelected: (_) => setState(() => _accountIdFilter = _accountIdFilter == a.id ? null : a.id),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          side: BorderSide.none,
                        ),
                      )),
                    ],
                  ),
                ),
              ],
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
                            isPending: op.isPending,
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

  Widget _quickAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
