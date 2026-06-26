import 'package:flutter/material.dart';
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

  const AddOperationScreen({super.key, this.type, this.operationId});

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

  bool get _isEditing => widget.operationId != null;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.type != null) _type = widget.type!;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isEditing && !_loaded) {
      _loaded = true;
      final store = context.read<FinanceStore>();
      final op = store.operations.where((o) => o.id == widget.operationId).firstOrNull;
      if (op != null) {
        _type = op.type;
        _amountCtrl.text = op.amount.toStringAsFixed(0);
        _accountId = op.accountId;
        _categoryId = op.categoryId;
        _toAccountId = op.toAccountId;
        if (op.comment != null) _commentCtrl.text = op.comment!;
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final store = context.read<FinanceStore>();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return;

    if (_isEditing) {
      store.updateOperation(Operation(
        id: widget.operationId!,
        type: _type,
        amount: amount,
        date: DateTime.now().toIso8601String(),
        accountId: _accountId ?? store.accounts.first.id,
        toAccountId: _type == 'transfer' ? _toAccountId : null,
        categoryId: _type != 'transfer' ? (_categoryId ?? store.categories.firstWhere((c) => c.type == _type).id) : null,
        comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
      ));
    } else {
      store.addOperation(Operation(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        type: _type,
        amount: amount,
        date: DateTime.now().toIso8601String(),
        accountId: _accountId ?? store.accounts.first.id,
        toAccountId: _type == 'transfer' ? _toAccountId : null,
        categoryId: _type != 'transfer' ? (_categoryId ?? store.categories.firstWhere((c) => c.type == _type).id) : null,
        comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
      ));
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
          title: _isEditing ? 'Редактировать' : 'Новая операция',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _typeBtn('expense', 'Расход'),
                  const SizedBox(width: 8),
                  _typeBtn('income', 'Доход'),
                  const SizedBox(width: 8),
                  _typeBtn('transfer', 'Перевод'),
                ],
              ),
              const SizedBox(height: 20),
              AppInput(label: 'Сумма', controller: _amountCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              Text('Счёт', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: InputDecoration(
                  filled: true, fillColor: AppColors.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: store.accounts.map((a) => DropdownMenuItem<String>(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: 16),
              if (_type != 'transfer') ...[
                Text('Категория', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: store.categories.where((c) => c.type == _type).map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ],
              if (_type == 'transfer') ...[
                Text('На счёт', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _toAccountId,
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: store.accounts.where((a) => a.id != _accountId).map((a) => DropdownMenuItem<String>(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => _toAccountId = v),
                ),
              ],
              const SizedBox(height: 16),
              AppInput(label: 'Комментарий', controller: _commentCtrl),
              const SizedBox(height: 24),
              AppButton(title: 'Сохранить', onPressed: _save),
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
            color: active ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppColors.primary : AppColors.border),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppColors.text,
          )),
        ),
      ),
    );
  }
}
