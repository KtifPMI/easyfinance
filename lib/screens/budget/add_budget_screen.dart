import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/budget.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class AddBudgetScreen extends StatefulWidget {
  final String? categoryId;
  const AddBudgetScreen({super.key, this.categoryId});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _limitCtrl = TextEditingController();
  String? _categoryId;

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
        final expenseCats = store.categories.where((c) => c.type == 'expense').toList();
        _categoryId ??= expenseCats.isNotEmpty ? expenseCats.first.id : null;

        return ScreenScaffold(
          title: context.tr('budget.new'),
          child: Column(
            children: [
              Text(context.tr('budget.category'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: InputDecoration(
                  filled: true, fillColor: AppColors.cardFor(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: expenseCats.map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
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
