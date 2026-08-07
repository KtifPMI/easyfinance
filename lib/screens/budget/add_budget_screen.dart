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
        final allCats = store.categories.where((c) => c.type == 'expense' || c.type == 'income').toList();
        final q = _searchCtrl.text.toLowerCase();
        final available = allCats.where((c) => !existingIds.contains(c.id) && (q.isEmpty || tCat(context, c.name).toLowerCase().contains(q))).toList();
        _categoryId ??= available.isNotEmpty ? available.first.id : null;

        return ScreenScaffold(
          title: context.tr('budget.new'),
          showLogo: false,
          child: Column(
            children: [
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
              Text(context.tr('budget.category'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
              const SizedBox(height: 8),
              if (available.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.tr('common.no_results'), style: TextStyle(color: AppColors.textSecondaryFor(context))),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.cardFor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: available.map((c) => DropdownMenuItem<String>(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(categoryIconFor(c, allCategories: store.categories), size: 18, color: c.type == 'income' ? AppColors.income : AppColors.expense),
                        const SizedBox(width: 8),
                        Expanded(child: Text(tCat(context, c.name), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
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
