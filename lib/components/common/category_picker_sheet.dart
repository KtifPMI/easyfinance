import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/category_icons.dart';
import '../../utils/translate_category.dart';

class CategoryPickerSheet {
  static Future<String?> show(
    BuildContext context, {
    required FinanceStore store,
    String? type,
    String? selectedId,
    bool showIncome = true,
    bool showExpense = true,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _CategoryPickerWidget(
        store: store,
        type: type,
        selectedId: selectedId,
        showIncome: showIncome,
        showExpense: showExpense,
      ),
    );
  }
}

class _CategoryPickerWidget extends StatefulWidget {
  final FinanceStore store;
  final String? type;
  final String? selectedId;
  final bool showIncome;
  final bool showExpense;

  const _CategoryPickerWidget({
    required this.store,
    this.type,
    this.selectedId,
    this.showIncome = true,
    this.showExpense = true,
  });

  @override
  State<_CategoryPickerWidget> createState() => _CategoryPickerWidgetState();
}

class _CategoryPickerWidgetState extends State<_CategoryPickerWidget> {
  String _search = '';
  String _typeFilter = '';

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.type ?? 'expense';
  }

  List<dynamic> _filteredCategories() {
    final cats = widget.store.categories.where((c) {
      if (widget.type != null && c.type != widget.type) return false;
      if (!widget.showIncome && c.type == 'income') return false;
      if (!widget.showExpense && c.type == 'expense') return false;
      return true;
    }).toList();

    final q = _search.toLowerCase();
    if (q.isNotEmpty) {
      return cats.where((c) => tCat(context, c.name).toLowerCase().contains(q)).toList();
    }
    return cats;
  }

  Map<String, int> _usageCounts() {
    final counts = <String, int>{};
    for (final op in widget.store.operations.where((o) => !o.isDeleted)) {
      if (op.categoryId != null) counts[op.categoryId!] = (counts[op.categoryId!] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCategories();
    final searching = _search.isNotEmpty;
    final counts = _usageCounts();

    Widget sectionHeader(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondaryFor(context))),
    );

    List<Widget> tilesFor(List<dynamic> cats, {bool grouped = false}) {
      if (!grouped) {
        return cats.map((c) => _categoryTile(context, c)).toList();
      }
      final groups = <String, List<dynamic>>{};
      for (final c in cats) {
        String parentName = '';
        if (c.parentId != null && c.parentId!.isNotEmpty) {
          final parent = widget.store.categories.where((p) => p.id == c.parentId).firstOrNull;
          if (parent != null) parentName = parent.name;
        }
        final key = parentName.isNotEmpty ? parentName : '-';
        groups.putIfAbsent(key, () => []);
        groups[key]!.add(c);
      }
      final out = <Widget>[];
      for (final entry in groups.entries) {
        if (entry.key != '-') {
          out.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(entry.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
          ));
        }
        out.addAll(entry.value.map((c) => _categoryTile(context, c)));
      }
      return out;
    }

    List<Widget> body;
    if (searching) {
      body = tilesFor(filtered, grouped: true);
    } else {
      final frequent = filtered.where((c) => (counts[c.id] ?? 0) > 0).toList()
        ..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
      final rest = filtered.where((c) => (counts[c.id] ?? 0) == 0).toList();
      body = <Widget>[];
      if (frequent.isNotEmpty) {
        body.add(sectionHeader(context.tr('categories.popular')));
        body.addAll(tilesFor(frequent));
        if (rest.isNotEmpty) body.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
      if (rest.isNotEmpty) {
        body.add(sectionHeader(context.tr('categories.all')));
        body.addAll(tilesFor(rest, grouped: true));
      }
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: context.tr('common.search'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true, fillColor: AppColors.cardFor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                if (widget.type == null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _typeFilter = _typeFilter == 'expense' ? 'income' : 'expense'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _typeFilter == 'income' ? AppColors.success.withValues(alpha: 0.15) : AppColors.expense.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _typeFilter == 'income' ? Icons.trending_up : Icons.trending_down,
                            size: 16,
                            color: _typeFilter == 'income' ? AppColors.success : AppColors.expense,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _typeFilter == 'income' ? context.tr('budget.income') : context.tr('budget.expense'),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _typeFilter == 'income' ? AppColors.success : AppColors.expense),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: body.length,
              itemBuilder: (_, i) => body[i],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTile(BuildContext context, dynamic c) {
    final catId = c.id as String;
    final catName = c.name as String;
    final catType = c.type as String;
    final color = catType == 'income' ? AppColors.income : AppColors.expense;
    final selected = widget.selectedId == catId;
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(categoryIconFor(c, allCategories: widget.store.categories), size: 18, color: color),
      ),
      title: Text(tCat(context, catName), style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      trailing: selected ? Icon(Icons.check, color: AppColors.primary, size: 20) : null,
      onTap: () => Navigator.pop(context, catId),
      dense: true,
    );
  }
}
