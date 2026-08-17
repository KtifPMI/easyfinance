import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/grouped_picker_sheet.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/budget.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/translate_category.dart';
import '../../utils/category_icons.dart';
import '../../utils/input_formatters.dart';

class AddBudgetScreen extends StatefulWidget {
  final String? categoryId;
  const AddBudgetScreen({super.key, this.categoryId});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _limitCtrl = TextEditingController();
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
    super.dispose();
  }

  void _switchType(String type) {
    setState(() {
      _typeFilter = type;
      _categoryId = null;
    });
  }

  void _save() {
    final store = context.read<FinanceStore>();
    final limit = double.tryParse(_limitCtrl.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    if (limit <= 0 || _categoryId == null) return;

    store.addBudget(Budget(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      categoryId: _categoryId!,
      limit: limit,
    ));
    Navigator.pop(context);
  }

  Future<void> _pickCategory(FinanceStore store) async {
    final existingIds = store.budgets.where((b) => !b.isDeleted).map((b) => b.categoryId).toSet();
    final cats = store.categories.where((c) => c.type == _typeFilter && !existingIds.contains(c.id)).toList();
    if (cats.isEmpty) return;
    final result = await GroupedPickerSheet.show<String>(
      context: context,
      title: context.tr('operations.category'),
      items: cats.map((c) => c.id).toList(),
      labelBuilder: (id) => tCat(context, store.categories.firstWhere((c) => c.id == id).name),
      groupBuilder: (id) {
        final c = store.categories.firstWhere((c) => c.id == id);
        if (c.parentId == null || c.parentId!.isEmpty) return '';
        final parent = store.categories.where((p) => p.id == c.parentId);
        return parent.isNotEmpty ? parent.first.name : '';
      },
      iconBuilder: (id) => categoryIconFor(store.categories.firstWhere((c) => c.id == id), allCategories: store.categories),
      colorBuilder: (id) => _typeFilter == 'income' ? AppColors.income : AppColors.expense,
      selectedId: _categoryId,
    );
    if (result != null) setState(() => _categoryId = result);
  }

  Widget _buildCategoryPicker(FinanceStore store) {
    final selected = store.categories.where((c) => c.id == _categoryId).map((c) => tCat(context, c.name)).firstOrNull;
    return GestureDetector(
      onTap: () => _pickCategory(store),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('operations.category'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardFor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderFor(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected ?? '',
                    style: TextStyle(fontSize: 16, color: selected != null ? AppColors.textFor(context) : AppColors.textSecondaryFor(context)),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondaryFor(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeTab(String type, String label, Color activeColor) {
    return GestureDetector(
      onTap: () => _switchType(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _typeFilter == type ? activeColor : AppColors.cardFor(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: _typeFilter == type ? Colors.white : AppColors.textFor(context),
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final existingIds = store.budgets.where((b) => !b.isDeleted).map((b) => b.categoryId).toSet();
        final available = store.categories.where((c) => c.type == _typeFilter && !existingIds.contains(c.id)).toList();

        return ScreenScaffold(
          title: context.tr('budget.new'),
          showLogo: false,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _typeTab('expense', context.tr('operations.type_expense'), AppColors.expense)),
                  const SizedBox(width: 8),
                  Expanded(child: _typeTab('income', context.tr('operations.type_income'), AppColors.income)),
                ],
              ),
              const SizedBox(height: 16),
              _buildCategoryPicker(store),
              if (available.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(context.tr('common.no_results'), style: TextStyle(color: AppColors.textSecondaryFor(context))),
                ),
              const SizedBox(height: 16),
              AppInput(label: context.tr('budget.limit'), controller: _limitCtrl, keyboardType: TextInputType.number, inputFormatters: [ThousandsSeparatorFormatter()]),
              const SizedBox(height: 24),
              AppButton(title: context.tr('budget.save'), onPressed: _save),
            ],
          ),
        );
      },
    );
  }
}
