import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_card.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/operation_template.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();

    return ScreenScaffold(
      title: context.tr('templates.title'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTemplateScreen())),
        ),
      ],
      child: store.templates.isEmpty
          ? Center(child: Text(context.tr('templates.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context))))
          : Column(children: store.templates.map((t) {
              final typeLabel = t.type == 'income' ? context.tr('operations.type_income')
                  : t.type == 'transfer' ? context.tr('operations.type_transfer')
                  : context.tr('operations.type_expense');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (t.type == 'income' ? AppColors.income : t.type == 'transfer' ? AppColors.transfer : AppColors.expense).withValues(alpha: 0.15),
                      child: Icon(
                        t.type == 'income' ? Icons.trending_up : t.type == 'transfer' ? Icons.swap_horiz : Icons.trending_down,
                        color: t.type == 'income' ? AppColors.income : t.type == 'transfer' ? AppColors.transfer : AppColors.expense,
                        size: 20,
                      ),
                    ),
                    title: Text(t.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                    subtitle: Text(typeLabel, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (t.amount > 0)
                          Text('${t.type == 'income' ? '+' : '-'}${t.amount.toStringAsFixed(0)} ₽',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                  color: t.type == 'income' ? AppColors.income : AppColors.expense)),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(context.tr('templates.confirm_delete')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('templates.cancel'))),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('templates.delete'))),
                                ],
                              ),
                            );
                            if (ok == true) store.deleteTemplate(t.id);
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/add-operation', arguments: {
                        'type': t.type,
                        'templateId': t.id,
                      });
                    },
                  ),
                ),
              );
            }).toList()),
    );
  }
}

class AddTemplateScreen extends StatefulWidget {
  const AddTemplateScreen({super.key});

  @override
  State<AddTemplateScreen> createState() => _AddTemplateScreenState();
}

class _AddTemplateScreenState extends State<AddTemplateScreen> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  String _type = 'expense';
  String? _accountId;
  String? _categoryId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<FinanceStore>();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    final now = DateTime.now().toIso8601String();

    await store.addTemplate(OperationTemplate(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name,
      type: _type,
      amount: amount,
      accountId: _accountId,
      categoryId: _categoryId,
      comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
      createdAt: now,
      updatedAt: now,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        if (_accountId == null && store.accounts.isNotEmpty) _accountId ??= store.accounts.first.id;
        if (_categoryId == null) {
          final cats = store.categories.where((c) => c.type == _type).toList();
          if (cats.isNotEmpty) _categoryId ??= cats.first.id;
        }

        return ScreenScaffold(
          title: context.tr('templates.new'),
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppInput(label: context.tr('templates.name'), controller: _nameCtrl),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _typeBtn('expense', context.tr('operations.type_expense')),
                    const SizedBox(width: 8),
                    _typeBtn('income', context.tr('operations.type_income')),
                    const SizedBox(width: 8),
                    _typeBtn('transfer', context.tr('operations.type_transfer')),
                  ],
                ),
                const SizedBox(height: 16),
                AppInput(label: context.tr('templates.amount'), controller: _amountCtrl, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                if (_type != 'transfer') ...[
                  Text(context.tr('operations.account'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _accountId,
                    decoration: InputDecoration(
                      filled: true, fillColor: AppColors.cardFor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: store.accounts.map((a) => DropdownMenuItem<String>(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                  const SizedBox(height: 16),
                  Text(context.tr('operations.category'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: InputDecoration(
                      filled: true, fillColor: AppColors.cardFor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: store.categories.where((c) => c.type == _type).map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
                ],
                const SizedBox(height: 16),
                AppInput(label: context.tr('templates.comment'), controller: _commentCtrl),
                const SizedBox(height: 24),
                AppButton(title: context.tr('templates.save'), onPressed: _save),
              ],
           ),
        );
      },
    );
  }

  Widget _typeBtn(String type, String label) {
    final active = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.cardFor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppColors.primary : AppColors.borderFor(context)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.textFor(context),
          )),
        ),
      ),
    );
  }
}
