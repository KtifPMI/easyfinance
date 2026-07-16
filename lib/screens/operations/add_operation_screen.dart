import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../theme/theme.dart';
import 'package:provider/provider.dart';
import '../../store/finance_store.dart';
import '../../models/operation.dart';

class AddOperationScreen extends StatefulWidget {
  final String? type;
  final String? operationId;
  final String? presetDate;
  final String? templateId;

  const AddOperationScreen({super.key, this.type, this.operationId, this.presetDate, this.templateId});

  @override
  State<AddOperationScreen> createState() => _AddOperationScreenState();
}

class _AddOperationScreenState extends State<AddOperationScreen> {
  String _type = 'expense';
  String? _accountId;
  String? _categoryId;
  String? _toAccountId;
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  bool get _isEditing => widget.operationId != null;
  bool _loaded = false;

  String _dateStr() {
    final now = DateTime.now();
    if (widget.presetDate != null) {
      final parts = widget.presetDate!.split('-').map(int.parse).toList();
      return DateTime(parts[0], parts[1], parts[2], now.hour, now.minute, now.second, now.millisecond, now.microsecond).toIso8601String();
    }
    return now.toIso8601String();
  }

  @override
  void initState() {
    super.initState();
    if (widget.type != null) _type = widget.type!;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      final store = context.read<FinanceStore>();

      if (widget.templateId != null) {
        final t = store.templates.where((t) => t.id == widget.templateId).firstOrNull;
        if (t != null) {
          _type = t.type;
          _amountCtrl.text = t.amount > 0 ? t.amount.toStringAsFixed(0) : '';
          _accountId = t.accountId;
          _categoryId = t.categoryId;
          _toAccountId = t.toAccountId;
          if (t.comment != null) _commentCtrl.text = t.comment!;
          if (t.tags != null) _tagsCtrl.text = t.tags!;
          return;
        }
      }

      if (_isEditing) {
        final op = store.operations.where((o) => o.id == widget.operationId).firstOrNull;
        if (op != null) {
          _type = op.type;
          _amountCtrl.text = op.amount.toStringAsFixed(0);
          _accountId = op.accountId;
          _categoryId = op.categoryId;
          _toAccountId = op.toAccountId;
          if (op.comment != null) _commentCtrl.text = op.comment!;
          if (op.tags != null) _tagsCtrl.text = op.tags!;
        }
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<FinanceStore>();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;
    if (store.accounts.isEmpty) return;

    final catId = _type != 'transfer' ? (_categoryId ?? store.categories.where((c) => c.type == _type).firstOrNull?.id) : null;
    if (_type != 'transfer' && catId == null) return;

    final op = Operation(
      id: _isEditing ? widget.operationId! : DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      type: _type,
      amount: amount,
      date: _dateStr(),
      accountId: _accountId ?? store.accounts.first.id,
      toAccountId: _type == 'transfer' ? _toAccountId : null,
      categoryId: catId,
      comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
      tags: _tagsCtrl.text.isNotEmpty ? _tagsCtrl.text : null,
    );

    if (_isEditing) {
      await store.updateOperation(op);
    } else {
      await store.addOperation(op);
    }

    if (!mounted) return;
    if (store.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(store.error!), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.pop(context);
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
          title: _isEditing ? context.tr('operations.edit') : context.tr('operations.add'),
           child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (store.templates.isNotEmpty && !_isEditing && widget.templateId == null) ...[
                InkWell(
                  onTap: () => _showTemplatePicker(context, store),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Text(context.tr('operations.use_template'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  _typeBtn('expense', context.tr('operations.type_expense')),
                  const SizedBox(width: 8),
                  _typeBtn('income', context.tr('operations.type_income')),
                  const SizedBox(width: 8),
                  _typeBtn('transfer', context.tr('operations.type_transfer')),
                ],
              ),
              const SizedBox(height: 20),
              AppInput(label: context.tr('operations.amount'), controller: _amountCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
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
              if (_type != 'transfer') ...[
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
              if (_type == 'transfer') ...[
                Text(context.tr('operations.to_account'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _toAccountId,
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.cardFor(context),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: store.accounts.where((a) => a.id != _accountId).map((a) => DropdownMenuItem<String>(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => _toAccountId = v),
                ),
              ],
              const SizedBox(height: 16),
              AppInput(label: context.tr('operations.comment'), controller: _commentCtrl),
              const SizedBox(height: 16),
              AppInput(label: context.tr('operations.tags'), controller: _tagsCtrl),
              const SizedBox(height: 24),
              AppButton(title: context.tr('operations.save'), onPressed: _save),
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

  void _showTemplatePicker(BuildContext context, FinanceStore store) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.tr('operations.use_template'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            ),
            ...store.templates.map((t) => ListTile(
              leading: Icon(
                t.type == 'income' ? Icons.trending_up : t.type == 'transfer' ? Icons.swap_horiz : Icons.trending_down,
                color: t.type == 'income' ? AppColors.income : t.type == 'transfer' ? AppColors.transfer : AppColors.expense,
              ),
              title: Text(t.name),
              subtitle: t.amount > 0 ? Text('${t.type == 'income' ? '+' : '-'}${t.amount.toStringAsFixed(0)} ₽',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _type = t.type;
                  if (t.amount > 0) _amountCtrl.text = t.amount.toStringAsFixed(0);
                  _accountId = t.accountId;
                  _categoryId = t.categoryId;
                  _toAccountId = t.toAccountId;
                  if (t.comment != null) _commentCtrl.text = t.comment!;
                  if (t.tags != null) _tagsCtrl.text = t.tags!;
                });
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
