import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/account.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class AddAccountScreen extends StatefulWidget {
  final String? accountId;
  const AddAccountScreen({super.key, this.accountId});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  String _type = 'account';
  bool _loaded = false;

  bool get _isEditing => widget.accountId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  void _loadExisting() {
    final store = context.read<FinanceStore>();
    final acc = store.accounts.where((a) => a.id == widget.accountId).firstOrNull;
    if (acc == null) return;
    _nameCtrl.text = acc.name;
    _balanceCtrl.text = acc.balance.toStringAsFixed(0);
    _type = acc.type;
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final store = context.read<FinanceStore>();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final balance = double.tryParse(_balanceCtrl.text.replaceAll(',', '.')) ?? 0;

    final account = Account(
      id: _isEditing ? widget.accountId! : DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name,
      balance: balance,
      type: _type,
      icon: _type == 'card' ? 'credit_card' : _type == 'savings' ? 'savings' : 'cash',
      color: _type == 'card' ? '#FFD700' : _type == 'savings' ? '#FF9800' : '#16A34A',
    );

    if (_isEditing) {
      store.updateAccount(account);
    } else {
      store.addAccount(account);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: _isEditing ? 'Редактировать счёт' : 'Новый счёт',
      child: Column(
        children: [
          AppInput(label: 'Название', controller: _nameCtrl),
          const SizedBox(height: 16),
          AppInput(label: 'Баланс', controller: _balanceCtrl, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          Text('Тип счёта', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: const [
              DropdownMenuItem(value: 'account', child: Text('Наличные')),
              DropdownMenuItem(value: 'card', child: Text('Карта')),
              DropdownMenuItem(value: 'savings', child: Text('Накопительный')),
              DropdownMenuItem(value: 'credit', child: Text('Кредитная карта')),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 24),
          AppButton(title: 'Сохранить', onPressed: _save),
        ],
      ),
    );
  }
}
