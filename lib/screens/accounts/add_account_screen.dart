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
  String _type = 'cash';
  String _currencyId = '1';
  int _state = 0;
  bool _isFavorite = false;

  final _descriptionCtrl = TextEditingController();
  final _annualRateCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _commissionOneCtrl = TextEditingController();
  final _commissionMonthlyCtrl = TextEditingController();
  final _openDateCtrl = TextEditingController();
  String _paymentType = 'annuity';
  int _paymentDay = 1;

  bool get _isCreditType => _type == 'credit' || _type == 'credit_card' || _type == 'loan_received';
  bool get _isDepositType => _type == 'deposit' || _type == 'insurance_savings' || _type == 'savings_plan' || _type == 'npf' || _type == 'pension';
  bool get _isDebitCard => _type == 'card';
  bool get _isDebtType => _type == 'credit' || _type == 'credit_card' || _type == 'loan_received';
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
        _descriptionCtrl.text = acc.description ?? '';
        _annualRateCtrl.text = acc.annualRate?.toStringAsFixed(2) ?? '0.00';
        _creditLimitCtrl.text = acc.creditLimit?.toStringAsFixed(2) ?? '';
        _commissionOneCtrl.text = acc.commissionOneTime?.toStringAsFixed(2) ?? '0.00';
        _commissionMonthlyCtrl.text = acc.commissionMonthly?.toStringAsFixed(2) ?? '0.00';
        _paymentType = acc.paymentType ?? 'annuity';
        _paymentDay = acc.paymentDay ?? 1;
        _openDateCtrl.text = acc.openDate ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _descriptionCtrl.dispose();
    _annualRateCtrl.dispose();
    _creditLimitCtrl.dispose();
    _commissionOneCtrl.dispose();
    _commissionMonthlyCtrl.dispose();
    _openDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<FinanceStore>();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    var balance = double.tryParse(_balanceCtrl.text.replaceAll(',', '.')) ?? 0;
    if (_isDebtType) balance = -balance.abs();

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
      icon: _iconForType(_type),
      color: _colorForType(_type),
      initBalance: initBalance,
      createdAt: createdAt.isNotEmpty ? createdAt : now,
      updatedAt: now,
      isArchived: _state == 2,
      isFavorite: _isFavorite,
      description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
      annualRate: (_isCreditType || _isDepositType) && _annualRateCtrl.text.isNotEmpty
          ? double.tryParse(_annualRateCtrl.text.replaceAll(',', '.'))
          : null,
      paymentType: _isCreditType ? _paymentType : null,
      creditLimit: _isCreditType && _creditLimitCtrl.text.isNotEmpty
          ? double.tryParse(_creditLimitCtrl.text.replaceAll(',', '.'))
          : null,
      paymentDay: _isCreditType ? _paymentDay : null,
      commissionOneTime: _isCreditType && _commissionOneCtrl.text.isNotEmpty
          ? double.tryParse(_commissionOneCtrl.text.replaceAll(',', '.'))
          : null,
      commissionMonthly: _isCreditType && _commissionMonthlyCtrl.text.isNotEmpty
          ? double.tryParse(_commissionMonthlyCtrl.text.replaceAll(',', '.'))
          : null,
      openDate: (_isDepositType || _isDebitCard) && _openDateCtrl.text.isNotEmpty
          ? _openDateCtrl.text.trim()
          : null,
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

  String _iconForType(String type) {
    switch (type) {
      case 'card': case 'credit_card': return 'credit_card';
      case 'credit': case 'loan_received': return 'credit_card';
      case 'loan_given': return 'payments';
      case 'deposit': case 'savings_plan': case 'insurance_savings':
      case 'npf': case 'pension': return 'savings';
      case 'electronic': return 'wallet';
      case 'bank_account': return 'account_balance';
      case 'broker': case 'stocks': case 'bonds':
      case 'other_securities': case 'pif': case 'ofbu':
      case 'fund': case 'pamm': case 'oms': return 'account_balance';
      case 'real_estate': case 'car': case 'motorcycle':
      case 'water_transport': case 'air_transport':
      case 'art': case 'business': case 'other_property': return 'account_balance';
      case 'bonus_card': return 'card_giftcard';
      default: return 'cash';
    }
  }

  String _colorForType(String type) {
    switch (type) {
      case 'card': case 'credit_card': return '#FFD700';
      case 'credit': case 'loan_received': return '#EF4444';
      case 'loan_given': return '#16A34A';
      case 'deposit': case 'savings_plan':
      case 'insurance_savings': case 'npf': case 'pension': return '#FF9800';
      case 'electronic': return '#00BCD4';
      case 'bank_account': return '#F59E0B';
      case 'broker': case 'stocks': case 'bonds':
      case 'other_securities': case 'pif': case 'ofbu':
      case 'fund': case 'pamm': case 'oms': return '#7C3AED';
      case 'real_estate': case 'car': case 'motorcycle':
      case 'water_transport': case 'air_transport':
      case 'art': case 'business': case 'other_property': return '#795548';
      case 'bonus_card': return '#E91E63';
      default: return '#16A34A';
    }
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
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          AppInput(label: context.tr('accounts.name'), controller: _nameCtrl),
          const SizedBox(height: 16),
          AppInput(label: _isDebtType ? context.tr('accounts.debt_amount') : context.tr('accounts.balance'), controller: _balanceCtrl, keyboardType: TextInputType.number),
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
            menuMaxHeight: 400,
            items: accountTypeLabels.entries.map((e) => DropdownMenuItem(
              value: _typeKeyFromId(e.key),
              child: Text(context.tr(e.value)),
            )).toList(),
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
          const SizedBox(height: 16),
          AppInput(
            label: context.tr('accounts.description'),
            controller: _descriptionCtrl,
            maxLines: 3,
          ),
          if (_isCreditType) ...[
            const SizedBox(height: 16),
            _sectionHeader(context, context.tr('accounts.credit')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    label: context.tr('accounts.annual_rate'),
                    controller: _annualRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentTypeDropdown(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    label: context.tr('accounts.credit_limit'),
                    controller: _creditLimitCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _paymentDay,
                    decoration: InputDecoration(
                      labelText: context.tr('accounts.payment_day'),
                      filled: true, fillColor: AppColors.cardFor(context),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                    onChanged: (v) => setState(() => _paymentDay = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    label: context.tr('accounts.commission_one_time'),
                    controller: _commissionOneCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppInput(
                    label: context.tr('accounts.commission_monthly'),
                    controller: _commissionMonthlyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
          if (_isDepositType) ...[
            const SizedBox(height: 16),
            _sectionHeader(context, context.tr('accounts.annual_rate')),
            const SizedBox(height: 12),
            AppInput(
              label: context.tr('accounts.annual_rate'),
              controller: _annualRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            AppInput(
              label: context.tr('accounts.open_date'),
              controller: _openDateCtrl,
              hint: 'YYYY-MM-DD',
            ),
          ],
          if (_isDebitCard) ...[
            const SizedBox(height: 16),
            AppInput(
              label: context.tr('accounts.open_date'),
              controller: _openDateCtrl,
              hint: 'YYYY-MM-DD',
            ),
          ],
          const SizedBox(height: 24),
          AppButton(title: context.tr('accounts.save'), onPressed: _save),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            AppButton(
              title: context.tr('accounts.delete'),
              onPressed: () => _delete(context),
              variant: 'danger',
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context)));
  }

  Widget _buildPaymentTypeDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _paymentType,
      decoration: InputDecoration(
        labelText: context.tr('accounts.payment_type'),
        filled: true, fillColor: AppColors.cardFor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: [
        DropdownMenuItem(value: 'annuity', child: Text(context.tr('accounts.payment_type.annuity'))),
        DropdownMenuItem(value: 'differentiated', child: Text(context.tr('accounts.payment_type.differentiated'))),
      ],
      onChanged: (v) => setState(() => _paymentType = v!),
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

String _typeKeyFromId(int id) {
  switch (id) {
    case 1: return 'cash';
    case 2: return 'card';
    case 5: return 'deposit';
    case 6: return 'loan_given';
    case 7: return 'loan_received';
    case 8: return 'credit_card';
    case 9: return 'credit';
    case 10: return 'oms';
    case 11: return 'stocks';
    case 12: return 'pif';
    case 13: return 'ofbu';
    case 14: return 'pension';
    case 15: return 'electronic';
    case 16: return 'bank_account';
    case 17: return 'real_estate';
    case 18: return 'car';
    case 19: return 'other_securities';
    case 20: return 'fund';
    case 21: return 'insurance_savings';
    case 22: return 'savings_plan';
    case 23: return 'npf';
    case 24: return 'water_transport';
    case 25: return 'art';
    case 26: return 'business';
    case 27: return 'other_property';
    case 28: return 'air_transport';
    case 29: return 'motorcycle';
    case 30: return 'bonds';
    case 31: return 'pamm';
    case 32: return 'broker';
    case 33: return 'bonus_card';
    default: return 'cash';
  }
}
