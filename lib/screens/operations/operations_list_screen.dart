import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/expandable_fab.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/operations/operation_list_item.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../../utils/translate_category.dart';

class OperationsListScreen extends StatefulWidget {
  const OperationsListScreen({super.key});

  @override
  State<OperationsListScreen> createState() => _OperationsListScreenState();
}

class _OperationsListScreenState extends State<OperationsListScreen> {
  String? _advTypeFilter;
  DateTime? _advDateFrom;
  DateTime? _advDateTo;
  String _advAmountFrom = '';
  String _advAmountTo = '';
  String _advComment = '';
  String? _advTagName;
  String? _advAccountId;

  bool get _hasAdvFilter =>
      _advTypeFilter != null ||
      _advDateFrom != null ||
      _advDateTo != null ||
      _advAmountFrom.isNotEmpty ||
      _advAmountTo.isNotEmpty ||
      _advComment.isNotEmpty ||
      _advTagName != null ||
      _advAccountId != null;

  void _resetAdvFilter() {
    setState(() {
      _advTypeFilter = null;
      _advDateFrom = null;
      _advDateTo = null;
      _advAmountFrom = '';
      _advAmountTo = '';
      _advComment = '';
      _advTagName = null;
      _advAccountId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        var ops = store.operations.toList();

        if (_advTypeFilter != null) {
          ops = ops.where((o) => o.type == _advTypeFilter).toList();
        }
        if (_advAccountId != null) {
          ops = ops.where((o) => o.accountId == _advAccountId || o.toAccountId == _advAccountId).toList();
        }

        if (_advTypeFilter != null) {
          ops = ops.where((o) => o.type == _advTypeFilter).toList();
        }
        if (_advDateFrom != null) {
          ops = ops.where((o) {
            final d = DateTime.tryParse(o.date);
            return d != null && !d.isBefore(_advDateFrom!);
          }).toList();
        }
        if (_advDateTo != null) {
          final to = DateTime(_advDateTo!.year, _advDateTo!.month, _advDateTo!.day, 23, 59, 59);
          ops = ops.where((o) {
            final d = DateTime.tryParse(o.date);
            return d != null && !d.isAfter(to);
          }).toList();
        }
        if (_advAmountFrom.isNotEmpty) {
          final min = double.tryParse(_advAmountFrom.replaceAll(',', '.')) ?? 0;
          ops = ops.where((o) => o.amount >= min).toList();
        }
        if (_advAmountTo.isNotEmpty) {
          final max = double.tryParse(_advAmountTo.replaceAll(',', '.')) ?? double.infinity;
          ops = ops.where((o) => o.amount <= max).toList();
        }
        if (_advComment.isNotEmpty) {
          final q = _advComment.toLowerCase();
          ops = ops.where((o) => (o.comment ?? '').toLowerCase().contains(q)).toList();
        }
        if (_advTagName != null) {
          ops = ops.where((o) => store.getTagsForOperation(o).contains(_advTagName)).toList();
        }

        final grouped = groupByDay(ops);

        return Stack(
          children: [
            ScreenScaffold(
              title: context.tr('operations.title'),
              actions: [
                IconButton(
                  icon: _hasAdvFilter
                      ? Icon(Icons.filter_list, color: AppColors.primary, size: 22)
                      : Icon(Icons.filter_list, color: AppColors.textSecondaryFor(context), size: 22),
                  onPressed: () => _showAdvFilterSheet(context, store),
                  tooltip: context.tr('filters.advanced_filter'),
                ),
              ],
              onRefresh: () => store.fetchAllData(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenHint(hintId: 'operations', text: context.tr('hints.operations')),
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
                              : tCat(context, cat?.name ?? context.tr('operations.no_category'));

                          return OperationListItem(
                            title: title,
                            subtitle: op.comment ?? acc?.name ?? '',
                            tags: store.getTagsForOperation(op),
                            formattedAmount: store.fmt(op.amount, fromCurrency: acc?.currency ?? 'RUB'),
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
        ),
        ExpandableFab(
          actions: [
            FabAction(icon: Icons.remove_circle_outline, label: context.tr('quick_actions.expense'), color: AppColors.expense, onTap: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'expense'})),
            FabAction(icon: Icons.add_circle_outline, label: context.tr('quick_actions.income'), color: AppColors.success, onTap: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'income'})),
            FabAction(icon: Icons.swap_horiz, label: context.tr('quick_actions.transfer'), color: AppColors.transfer, onTap: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'transfer'})),
            FabAction(icon: Icons.document_scanner, label: context.tr('quick_actions.receipt'), color: AppColors.accent, onTap: () => Navigator.pushNamed(context, '/scan-receipt')),
          ],
        ),
      ],
    );
  },
);
  }

  void _showAdvFilterSheet(BuildContext context, FinanceStore store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollCtrl) {
                final tagSet = <String>{};
                for (final op in store.operations) {
                  for (final t in store.getTagsForOperation(op)) {
                    tagSet.add(t);
                  }
                }
                final tags = tagSet.toList()..sort();

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: ListView(
                    controller: scrollCtrl,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.tr('filters.advanced_filter'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {});
                              setState(() => _resetAdvFilter());
                            },
                            child: Text(context.tr('filters.reset'), style: TextStyle(color: AppColors.danger, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(context.tr('filters.type'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(label: Text(context.tr('filters.all_types')), selected: _advTypeFilter == null, onSelected: (_) => setSheetState(() => _advTypeFilter = null), selectedColor: AppColors.primary.withValues(alpha: 0.15)),
                          ChoiceChip(label: Text(context.tr('filters.income')), selected: _advTypeFilter == 'income', onSelected: (_) => setSheetState(() => _advTypeFilter = _advTypeFilter == 'income' ? null : 'income'), selectedColor: AppColors.primary.withValues(alpha: 0.15)),
                          ChoiceChip(label: Text(context.tr('filters.expense')), selected: _advTypeFilter == 'expense', onSelected: (_) => setSheetState(() => _advTypeFilter = _advTypeFilter == 'expense' ? null : 'expense'), selectedColor: AppColors.primary.withValues(alpha: 0.15)),
                          ChoiceChip(label: Text(context.tr('filters.transfer')), selected: _advTypeFilter == 'transfer', onSelected: (_) => setSheetState(() => _advTypeFilter = _advTypeFilter == 'transfer' ? null : 'transfer'), selectedColor: AppColors.primary.withValues(alpha: 0.15)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (store.accounts.length > 1) ...[
                        Text(context.tr('filters.account'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(label: Text(context.tr('filters.all_accounts')), selected: _advAccountId == null, onSelected: (_) => setSheetState(() => _advAccountId = null), selectedColor: AppColors.primary.withValues(alpha: 0.15)),
                            ...store.accounts.map((a) => ChoiceChip(
                              label: Text(a.name),
                              selected: _advAccountId == a.id,
                              onSelected: (_) => setSheetState(() => _advAccountId = _advAccountId == a.id ? null : a.id),
                              selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            )),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      Text(context.tr('filters.period'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _dateTile(context, context.tr('filters.from_date'), _advDateFrom, (d) => setSheetState(() => _advDateFrom = d)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dateTile(context, context.tr('filters.to_date'), _advDateTo, (d) => setSheetState(() => _advDateTo = d)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(context.tr('filters.amount'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(labelText: context.tr('filters.from_amount'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => _advAmountFrom = v,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(labelText: context.tr('filters.to_amount'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => _advAmountTo = v,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(context.tr('filters.comment'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(hintText: context.tr('filters.comment_hint'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, prefixIcon: const Icon(Icons.search, size: 20)),
                        onChanged: (v) => _advComment = v,
                      ),

                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(context.tr('filters.tag'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(label: Text(context.tr('filters.all_tags')), selected: _advTagName == null, onSelected: (_) => setSheetState(() => _advTagName = null), selectedColor: AppColors.primary.withValues(alpha: 0.15)),
                            ...tags.map((t) => ChoiceChip(
                              label: Text(t),
                              selected: _advTagName == t,
                              onSelected: (_) => setSheetState(() => _advTagName = _advTagName == t ? null : t),
                              selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            )),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {});
                            Navigator.pop(ctx);
                          },
                          child: Text(context.tr('filters.apply'), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _dateTile(BuildContext context, String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onChanged(value != null && picked == value ? null : picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: value != null ? AppColors.primary : AppColors.textSecondaryFor(context)),
            const SizedBox(width: 8),
            Expanded(
              child:               Text(
                value != null ? formatDate(value.toIso8601String().substring(0, 10)) : label,
                style: TextStyle(fontSize: 13, color: value != null ? AppColors.textFor(context) : AppColors.textSecondaryFor(context)),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Icon(Icons.close, size: 14, color: AppColors.textSecondaryFor(context)),
              ),
          ],
        ),
      ),
    );
  }
}
