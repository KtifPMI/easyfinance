import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/expandable_fab.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/operations/operation_list_item.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/color_utils.dart';
import '../../utils/format.dart';
import '../../utils/translate_category.dart';
import '../../utils/category_icons.dart';

class OperationsListScreen extends StatefulWidget {
  final bool showBackButton;
  const OperationsListScreen({super.key, this.showBackButton = true});

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
  List<String> _advAccountIds = [];
  bool _sortByInputTime = false;
  bool _sortByUpdated = false;
  String? _reportCategoryId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      if (args['sort'] == 'date_desc') { _sortByInputTime = false; _sortByUpdated = false; }
      if (_reportCategoryId == null) {
        setState(() {
          _reportCategoryId = args['categoryId'] as String?;
          final dateFrom = args['dateFrom'] as String?;
          final dateTo = args['dateTo'] as String?;
          if (dateFrom != null) _advDateFrom = DateTime.tryParse(dateFrom);
          if (dateTo != null) _advDateTo = DateTime.tryParse(dateTo);
        });
      }
    }
  }

  bool get _hasAdvFilter =>
      _advTypeFilter != null ||
      _advDateFrom != null ||
      _advDateTo != null ||
      _advAmountFrom.isNotEmpty ||
      _advAmountTo.isNotEmpty ||
      _advComment.isNotEmpty ||
      _advTagName != null ||
      _advAccountIds.isNotEmpty;

  void _resetAdvFilter() {
    setState(() {
      _advTypeFilter = null;
      _advDateFrom = null;
      _advDateTo = null;
      _advAmountFrom = '';
      _advAmountTo = '';
      _advComment = '';
      _advTagName = null;
      _advAccountIds = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        var ops = store.operations.where((o) => !o.isDeleted).toList();

        if (_advTypeFilter != null) {
          ops = ops.where((o) => o.type == _advTypeFilter).toList();
        }
        if (_reportCategoryId != null) {
          ops = ops.where((o) => o.categoryId == _reportCategoryId).toList();
        }
        if (_advAccountIds.isNotEmpty) {
          ops = ops.where((o) => _advAccountIds.contains(o.accountId) || (o.toAccountId != null && _advAccountIds.contains(o.toAccountId))).toList();
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
          ops = ops.where((o) {
            if ((o.comment ?? '').toLowerCase().contains(q)) return true;
            if (store.getTagsForOperation(o).any((t) => t.toLowerCase().contains(q))) return true;
            return false;
          }).toList();
        }
        if (_advTagName != null) {
          ops = ops.where((o) => store.getTagsForOperation(o).contains(_advTagName)).toList();
        }

        if (_sortByUpdated) {
          ops.sort((a, b) => (b.updatedAt ?? b.date).compareTo(a.updatedAt ?? a.date));
        } else if (_sortByInputTime) {
          ops.sort((a, b) => (b.clientId ?? '').compareTo(a.clientId ?? ''));
        } else {
          ops.sort((a, b) => b.date.compareTo(a.date));
        }

        final grouped = groupByDay(ops);

        return Stack(
          children: [
            ScreenScaffold(
              title: context.tr('operations.title'),
              showBackButton: widget.showBackButton,
              actions: [
                IconButton(
                  icon: _hasAdvFilter
                      ? Icon(Icons.search, color: AppColors.primary, size: 22)
                      : Icon(Icons.search, color: AppColors.textSecondaryFor(context), size: 22),
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
              Row(
                children: [
                  ChoiceChip(
                    label: Text(context.tr('operations.sort_date')),
                    selected: !_sortByUpdated,
                    onSelected: (_) => setState(() => _sortByUpdated = false),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.update, size: 16, color: _sortByUpdated ? AppColors.primary : AppColors.textSecondaryFor(context)),
                        const SizedBox(width: 4),
                        Text(context.tr('operations.sort_updated')),
                      ],
                    ),
                    selected: _sortByUpdated,
                    onSelected: (_) => setState(() => _sortByUpdated = true),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_hasAdvFilter || _reportCategoryId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ops.isEmpty
                              ? context.tr('filters.no_results')
                              : context.tr('filters.count', namedArgs: {'count': ops.length.toString()}),
                          style: TextStyle(fontSize: 14, color: ops.isEmpty ? AppColors.warning : AppColors.textSecondaryFor(context)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _resetAdvFilter();
                          _reportCategoryId = null;
                          _sortByInputTime = false;
                          _sortByUpdated = false;
                        }),
                        child: Text(context.tr('filters.reset'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              if (ops.isEmpty && !_hasAdvFilter && _reportCategoryId == null)
                Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(context.tr('operations.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context)))))
              else if (_sortByInputTime || _sortByUpdated)
                _buildFlatList(context, store, ops)
              else
                ...grouped.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(formatDayLabel(entry.key, context), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
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
                          } else {
                            iconData = cat != null ? categoryIconFor(cat, allCategories: store.categories) : (op.type == 'income' ? Icons.trending_up : Icons.trending_down);
                            iconColor = op.type == 'income' ? AppColors.income : AppColors.expense;
                          }
                          final title = op.type == 'transfer'
                              ? '${acc?.name ?? ''} → ${toAcc?.name ?? ''}'
                              : tCat(context, cat?.name ?? context.tr('operations.no_category'));

                          return OperationListItem(
                            title: title,
                            subtitle: op.comment ?? acc?.name ?? '',
                            tags: store.getTagsForOperation(op),
                            formattedAmount: store.fmtOps(op.amount, fromCurrency: acc?.currency ?? 'RUB', date: op.date),
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

  Widget _buildFlatList(BuildContext context, FinanceStore store, List<dynamic> ops) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: ops.map((op) {
          final cat = store.getCategory(op.categoryId);
          final acc = store.getAccount(op.accountId);
          final toAcc = store.getAccount(op.toAccountId);
          final IconData iconData;
          final Color iconColor;
          if (op.type == 'transfer') {
            iconData = Icons.swap_horiz;
            iconColor = AppColors.transfer;
          } else {
            iconData = cat != null ? categoryIconFor(cat, allCategories: store.categories) : (op.type == 'income' ? Icons.trending_up : Icons.trending_down);
            iconColor = op.type == 'income' ? AppColors.income : AppColors.expense;
          }
          final title = op.type == 'transfer'
              ? '${acc?.name ?? ''} → ${toAcc?.name ?? ''}'
              : tCat(context, cat?.name ?? context.tr('operations.no_category'));
          return OperationListItem(
            title: title,
            subtitle: op.comment ?? acc?.name ?? '',
            tags: store.getTagsForOperation(op),
            formattedAmount: store.fmtOps(op.amount, fromCurrency: acc?.currency ?? 'RUB', date: op.date),
            type: op.type,
            icon: iconData,
            iconColor: iconColor,
            onTap: () => Navigator.pushNamed(context, '/operation-detail', arguments: {'operationId': op.id}),
            isPending: op.isPending,
          );
        }).toList(),
      ),
    );
  }

  void _showAccountPicker(BuildContext context, FinanceStore store, void Function(void Function()) setSheetState) {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) {
          final q = searchCtrl.text.toLowerCase();
          final filtered = q.isEmpty
              ? store.accounts
              : store.accounts.where((a) => a.name.toLowerCase().contains(q)).toList();
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (ctx, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: context.tr('common.search'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setPickerState(() {}),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final a = filtered[i];
                      final selected = _advAccountIds.contains(a.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) {
                          setPickerState(() {
                            if (v == true) {
                              _advAccountIds = [..._advAccountIds, a.id];
                            } else {
                              _advAccountIds = _advAccountIds.where((id) => id != a.id).toList();
                            }
                          });
                          setSheetState(() {});
                        },
                        secondary: Icon(_accountIcon(a.icon), color: parseColor(a.color)),
                        title: Text(a.name, style: const TextStyle(fontSize: 15)),
                        activeColor: AppColors.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTagPicker(BuildContext context, List<String> tags, void Function(void Function()) setSheetState) {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) {
          final q = searchCtrl.text.toLowerCase();
          final filtered = q.isEmpty ? tags : tags.where((t) => t.toLowerCase().contains(q)).toList();
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (ctx, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: context.tr('common.search'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) => setPickerState(() {}),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return ListTile(
                          leading: Icon(Icons.clear, color: AppColors.danger),
                          title: Text(context.tr('filters.all_tags'), style: const TextStyle(fontSize: 15)),
                          onTap: () {
                            setPickerState(() => _advTagName = null);
                            setSheetState(() {});
                          Navigator.pop(ctx);
                        },
                      );
                      }
                      final t = filtered[i - 1];
                      return ListTile(
                        leading: Icon(Icons.label, color: _advTagName == t ? AppColors.primary : AppColors.textSecondaryFor(context)),
                        title: Text(t, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: _advTagName == t ? FontWeight.w600 : FontWeight.w400)),
                        trailing: _advTagName == t ? Icon(Icons.check, color: AppColors.primary) : null,
                        onTap: () {
                          setPickerState(() => _advTagName = _advTagName == t ? null : t);
                          setSheetState(() {});
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
                          Text(context.tr('filters.advanced_filter'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {});
                              setState(() => _resetAdvFilter());
                            },
                            child: Text(context.tr('filters.reset'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(context.tr('filters.type'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
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
                        Text(context.tr('filters.account'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showAccountPicker(context, store, setSheetState),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.cardFor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _advAccountIds.isEmpty ? AppColors.borderFor(context) : AppColors.primary),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.account_balance_wallet, size: 18, color: _advAccountIds.isEmpty ? AppColors.textSecondaryFor(context) : AppColors.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _advAccountIds.isEmpty
                                        ? context.tr('filters.all_accounts')
                                        : _advAccountIds.map((id) => store.accounts.where((a) => a.id == id).firstOrNull?.name ?? id).join(', '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _advAccountIds.isEmpty ? AppColors.textSecondaryFor(context) : AppColors.textFor(context)),
                                  ),
                                ),
                                Icon(Icons.unfold_more, size: 18, color: AppColors.textSecondaryFor(context)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      Text(context.tr('filters.period'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
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

                      Text(context.tr('filters.amount'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
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

                      Text(context.tr('filters.comment'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(hintText: context.tr('filters.comment_hint'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true, prefixIcon: const Icon(Icons.search, size: 20)),
                        onChanged: (v) => _advComment = v,
                      ),

                      const SizedBox(height: 20),
                      Text(context.tr('filters.tag'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showTagPicker(context, tags, setSheetState),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.cardFor(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _advTagName == null ? AppColors.borderFor(context) : AppColors.primary),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.label_outline, size: 18, color: _advTagName == null ? AppColors.textSecondaryFor(context) : AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _advTagName ?? context.tr('filters.all_tags'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _advTagName == null ? AppColors.textSecondaryFor(context) : AppColors.textFor(context)),
                                ),
                              ),
                              Icon(Icons.unfold_more, size: 18, color: AppColors.textSecondaryFor(context)),
                            ],
                          ),
                        ),
                      ),
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
                          child: Text(context.tr('filters.apply'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
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
                style: TextStyle(fontSize: 14, color: value != null ? AppColors.textFor(context) : AppColors.textSecondaryFor(context)),
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

  IconData _accountIcon(String icon) {
    const map = {'cash': Icons.money, 'credit_card': Icons.credit_card, 'savings': Icons.savings, 'account_balance': Icons.account_balance, 'wallet': Icons.account_balance_wallet, 'payments': Icons.payments, 'currency_ruble': Icons.currency_ruble, 'card_giftcard': Icons.card_giftcard};
    return map[icon] ?? Icons.account_balance_wallet;
  }
}
