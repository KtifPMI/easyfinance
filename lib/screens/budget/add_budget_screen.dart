import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/budget.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/translate_category.dart';
import '../../utils/category_icons.dart';

class AddBudgetScreen extends StatefulWidget {
  final String? categoryId;
  const AddBudgetScreen({super.key, this.categoryId});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _limitCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String? _categoryId;
  String _typeFilter = 'expense';

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categoryId;
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final store = context.read<FinanceStore>();
    final limit = double.tryParse(_limitCtrl.text.replaceAll(',', '.')) ?? 0;
    if (limit <= 0 || _categoryId == null) return;

    store.addBudget(Budget(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      categoryId: _categoryId!,
      limit: limit,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final existingIds = store.budgets.where((b) => !b.isDeleted).map((b) => b.categoryId).toSet();
        final allCats = store.categories.where((c) => c.type == _typeFilter).toList();
        final q = _searchCtrl.text.toLowerCase();

        final grouped = <String, List<dynamic>>{};
        for (final c in allCats.where((c) => !existingIds.contains(c.id) && (q.isEmpty || tCat(context, c.name).toLowerCase().contains(q)))) {
          String parentName = '';
          if (c.parentId != null && c.parentId!.isNotEmpty) {
            final parent = store.categories.where((p) => p.id == c.parentId).firstOrNull;
            if (parent != null) parentName = parent.name;
          }
          final key = parentName.isNotEmpty ? parentName : '-';
          grouped.putIfAbsent(key, () => []);
          grouped[key]!.add(c);
        }
        final available = grouped.entries.expand((e) => e.value).toList();
        _categoryId ??= available.isNotEmpty ? (available.first as dynamic).id : null;

        return ScreenScaffold(
          title: context.tr('budget.new'),
          showLogo: false,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _typeFilter = 'expense'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _typeFilter == 'expense' ? AppColors.expense : AppColors.cardFor(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(context.tr('operations.type_expense'), textAlign: TextAlign.center, style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: _typeFilter == 'expense' ? Colors.white : AppColors.textFor(context),
                        )),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _typeFilter = 'income'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _typeFilter == 'income' ? AppColors.income : AppColors.cardFor(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(context.tr('operations.type_income'), textAlign: TextAlign.center, style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: _typeFilter == 'income' ? Colors.white : AppColors.textFor(context),
                        )),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: context.tr('common.search'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true, fillColor: AppColors.cardFor(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (available.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.tr('common.no_results'), style: TextStyle(color: AppColors.textSecondaryFor(context))),
                )
              else
                Expanded(
                  child: ListView(
                    children: grouped.entries.map((entry) {
                      final parentName = entry.key;
                      final cats = entry.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (parentName != '-')
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Text(parentName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
                            ),
                          ...cats.map((c) => RadioListTile<String>(
                            value: (c as dynamic).id as String,
                            groupValue: _categoryId,
                            title: Row(
                              children: [
                                Icon(categoryIconFor(c as dynamic, allCategories: store.categories), size: 18, color: _typeFilter == 'income' ? AppColors.income : AppColors.expense),
                                const SizedBox(width: 8),
                                Expanded(child: Text(tCat(context, (c as dynamic).name as String), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14))),
                              ],
                            ),
                            onChanged: (v) => setState(() => _categoryId = v),
                            activeColor: AppColors.primary,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          )),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 16),
              AppInput(label: context.tr('budget.limit'), controller: _limitCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 24),
              AppButton(title: context.tr('budget.save'), onPressed: _save),
            ],
          ),
        );
      },
    );
  }
}
