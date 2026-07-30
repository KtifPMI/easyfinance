import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/account.dart';
import '../../services/currency_rate_service.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

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
  String _currencyId = '1';
  int _state = 0;
  bool _isFavorite = false;

  bool get _isEditing => widget.accountId != null;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isEditing && !_loaded) {
      _loaded = true;
      final store = context.read<FinanceStore>();
      final acc = store.accounts.where((a) => a.id == widget.accountId).firstOrNull;
      if (acc != null) {
        _nameCtrl.text = acc.name;
        _balanceCtrl.text = acc.balance.toStringAsFixed(0);
        _type = acc.type;
        _currencyId = acc.currencyId ?? '1';
        _isFavorite = acc.isFavorite;
        _state = acc.isArchived ? 2 : 0;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<FinanceStore>();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final balance = double.tryParse(_balanceCtrl.text.replaceAll(',', '.')) ?? 0;

    String createdAt = '';
    double initBalance = balance;

    if (_isEditing) {
      final existing = store.accounts.where((a) => a.id == widget.accountId).firstOrNull;
      if (existing != null) {
        createdAt = existing.createdAt;
        double opsDelta = 0;
        for (final op in store.operations.where((o) => !o.isDeleted)) {
          if (op.type == 'expense' && op.accountId == existing.id) {
            opsDelta -= op.amount;
          } else if (op.type == 'income' && op.accountId == existing.id) {
            opsDelta += op.amount;
          } else if (op.type == 'transfer') {
            if (op.accountId == existing.id) opsDelta -= op.amount;
            if (op.toAccountId == existing.id) {
              if (op.transferAmount != null && op.transferAmount! > 0) {
                opsDelta += op.transferAmount!;
              } else {
                final src = store.getAccount(op.accountId);
                if (src != null && src.currency != existing.currency) {
                  opsDelta += CurrencyRateService.convert(op.amount, src.currency, existing.currency, store.rates);
                } else {
                  opsDelta += op.amount;
                }
              }
            }
          }
        }
        initBalance = balance - opsDelta;
      }
    }

    final now = formatApiDateTime();
    final account = Account(
      id: _isEditing ? widget.accountId! : DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name,
      balance: balance,
      type: _type,
      currencyId: _currencyId,
      icon: _type == 'card' ? 'credit_card' : _type == 'savings' ? 'savings' : 'cash',
      color: _type == 'card' ? '#FFD700' : _type == 'savings' ? '#FF9800' : '#16A34A',
      initBalance: initBalance,
      createdAt: createdAt.isNotEmpty ? createdAt : now,
      updatedAt: now,
      isArchived: _state == 2,
      isFavorite: _isFavorite,
    );

    if (_isEditing) {
      await store.updateAccount(account, state: _state.toString());
    } else {
      await store.addAccount(account, state: _state.toString());
    }
    if (store.error == null) {
      store.updateAccountFavorite(account.id, _isFavorite);
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
    final store = context.watch<FinanceStore>();
    final currencies = store.currencies;
    final currencyItems = currencies.isNotEmpty
        ? currencies.map((c) => DropdownMenuItem(
            value: c['id']?.toString() ?? '1',
            child: Text('${c['code'] ?? c['name'] ?? 'RUB'}'),
          )).toList()
        : _defaultCurrencyItems();

    return ScreenScaffold(
      title: _isEditing ? context.tr('accounts.edit') : context.tr('accounts.new'),
      child: Column(
        children: [
          AppInput(label: context.tr('accounts.name'), controller: _nameCtrl),
          const SizedBox(height: 16),
          AppInput(label: context.tr('accounts.balance'), controller: _balanceCtrl, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          Text(context.tr('accounts.type'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: [
              DropdownMenuItem(value: 'account', child: Text(context.tr('accounts.type.cash'))),
              DropdownMenuItem(value: 'card', child: Text(context.tr('accounts.type.card'))),
              DropdownMenuItem(value: 'savings', child: Text(context.tr('accounts.type.savings'))),
              DropdownMenuItem(value: 'credit', child: Text(context.tr('accounts.type.credit'))),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 16),
          Text(context.tr('accounts.currency'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _currencyId,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: currencyItems,
            onChanged: (v) => setState(() => _currencyId = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _state,
            decoration: InputDecoration(
              labelText: context.tr('accounts.state'),
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: [
              DropdownMenuItem(value: 0, child: Text(context.tr('accounts.state.active'))),
              DropdownMenuItem(value: 1, child: Text(context.tr('accounts.state.hidden'))),
            ],
            onChanged: (v) => setState(() => _state = v!),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(context.tr('accounts.favorite')),
            value: _isFavorite,
            onChanged: (v) => setState(() => _isFavorite = v),
            contentPadding: EdgeInsets.zero,
            activeTrackColor: AppColors.primary,
          ),
          const SizedBox(height: 8),
          AppButton(title: context.tr('accounts.save'), onPressed: _save),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            AppButton(
              title: context.tr('accounts.delete'),
              onPressed: () => _delete(context),
              variant: 'danger',
            ),
          ],
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _defaultCurrencyItems() {
    const codes = {'1': 'RUB', '2': 'USD', '3': 'EUR', '4': 'GBP', '5': 'CHF', '6': 'CNY', '7': 'JPY', '8': 'BYN', '9': 'UAH', '10': 'KZT', '11': 'PLN', '12': 'CZK', '13': 'SEK', '14': 'NOK'};
    return codes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList();
  }

  void _delete(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('accounts.confirm_delete')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('accounts.cancel'))),
          TextButton(
            onPressed: () {
              context.read<FinanceStore>().deleteAccount(widget.accountId!);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(context.tr('accounts.delete'), style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}
