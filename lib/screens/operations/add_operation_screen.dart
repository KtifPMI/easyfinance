import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/calculator_input.dart';
import '../../components/common/grouped_picker_sheet.dart';
import '../../components/common/screen_scaffold.dart';
import '../../utils/translate_category.dart';
import '../../utils/format.dart';
import '../../theme/theme.dart';
import 'package:provider/provider.dart';
import '../../store/finance_store.dart';
import '../../models/operation.dart';
import '../../services/currency_rate_service.dart';

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
  late DateTime _selectedDT;

  @override
  void initState() {
    super.initState();
    if (widget.type != null) _type = widget.type!;
    _selectedDT = _parseInitialDate();
  }

  DateTime _parseInitialDate() {
    if (widget.presetDate != null) {
      final parts = widget.presetDate!.split('-').map(int.parse).toList();
      if (parts.length == 3) {
        final now = DateTime.now();
        return DateTime(parts[0], parts[1], parts[2], now.hour, now.minute);
      }
    }
    return DateTime.now();
  }

  String _dateStr() => formatApiDateTime(_selectedDT);

  String _formatDisplayDate() {
    final m = _selectedDT.month;
    const keys = ['month.short.1', 'month.short.2', 'month.short.3', 'month.short.4', 'month.short.5', 'month.short.6', 'month.short.7', 'month.short.8', 'month.short.9', 'month.short.10', 'month.short.11', 'month.short.12'];
    return '${_selectedDT.day} ${context.tr(keys[m - 1])}. ${_selectedDT.year}, ${_selectedDT.hour.toString().padLeft(2, '0')}:${_selectedDT.minute.toString().padLeft(2, '0')}';
  }

  void _showDateTimePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDT,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: context.locale,
    );
    if (date == null || !mounted) return;

    int hour = _selectedDT.hour;
    int minute = _selectedDT.minute;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('operations.select_time'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _timeStepper(() => setSheetState(() { if (hour < 23) hour++; }), () => setSheetState(() { if (hour > 0) hour--; }), hour, 23),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textFor(context))),
                  ),
                  _timeStepper(() => setSheetState(() { if (minute < 59) minute++; }), () => setSheetState(() { if (minute > 0) minute--; }), minute, 59),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() => _selectedDT = DateTime(date.year, date.month, date.day, hour, minute));
                    Navigator.pop(ctx);
                  },
                  child: Text(context.tr('common.ok'), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeStepper(VoidCallback onUp, VoidCallback onDown, int current, int max) {
    return Column(
      children: [
        GestureDetector(onTap: onUp, child: Icon(Icons.keyboard_arrow_up, size: 28, color: AppColors.textSecondaryFor(context))),
        const SizedBox(height: 4),
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(current.toString().padLeft(2, '0'), textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
        ),
        const SizedBox(height: 4),
        GestureDetector(onTap: current > 0 ? onDown : null, child: Icon(Icons.keyboard_arrow_down, size: 28, color: current > 0 ? AppColors.textSecondaryFor(context) : AppColors.textSecondary)),
      ],
    );
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

    final accountId = _accountId ?? store.accounts.first.id;
    final toAccountId = _type == 'transfer' ? _toAccountId : null;
    double? transferAmount;
    if (_type == 'transfer' && toAccountId != null) {
      final src = store.getAccount(accountId);
      final dst = store.getAccount(toAccountId);
      if (src != null && dst != null && src.currency != dst.currency) {
        transferAmount = CurrencyRateService.convert(amount, src.currency, dst.currency, store.rates);
      }
    }
    final clientId = _isEditing ? null : DateTime.now().microsecondsSinceEpoch.toString();
    final op = Operation(
      id: _isEditing ? widget.operationId! : clientId!,
      type: _type,
      amount: amount,
      transferAmount: transferAmount,
      date: _dateStr(),
      accountId: accountId,
      toAccountId: toAccountId,
      categoryId: catId,
      comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
      tags: _tagsCtrl.text.isNotEmpty ? _tagsCtrl.text : null,
      clientId: clientId,
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
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/main');
    }
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
          showLogo: false,
          actions: [
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/main');
                  }
                },
                tooltip: context.tr('common.close'),
              ),
          ],
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
              CalculatorInput(controller: _amountCtrl, label: context.tr('operations.amount')),
              const SizedBox(height: 16),
              _buildPicker(
                label: context.tr('operations.account'),
                value: store.accounts.where((a) => a.id == _accountId).map((a) => a.name).firstOrNull,
                onTap: () async {
                  final result = await GroupedPickerSheet.show<String>(
                    context: context,
                    title: context.tr('operations.account'),
                    items: store.accounts.map((a) => a.id).toList(),
                    labelBuilder: (id) => store.accounts.firstWhere((a) => a.id == id).name,
                    groupBuilder: (id) {
                      final a = store.accounts.firstWhere((a) => a.id == id);
                      return a.currency;
                    },
                    subtitleBuilder: (id) {
                      final a = store.accounts.firstWhere((a) => a.id == id);
                      return '${a.balance.toStringAsFixed(2)} ${a.currency}';
                    },
                    iconBuilder: (id) => _accountIcon(store.accounts.firstWhere((a) => a.id == id).icon),
                    colorBuilder: (id) => _hexToColor(store.accounts.firstWhere((a) => a.id == id).color),
                    selectedId: _accountId,
                  );
                  if (result != null) setState(() => _accountId = result);
                },
              ),
              const SizedBox(height: 16),
              if (_type != 'transfer') ...[
                _buildPicker(
                  label: context.tr('operations.category'),
                  value: store.categories.where((c) => c.id == _categoryId).map((c) => tCat(context, c.name)).firstOrNull,
                  onTap: () async {
                    final result = await GroupedPickerSheet.show<String>(
                      context: context,
                      title: context.tr('operations.category'),
                      items: store.categories.where((c) => c.type == _type).map((c) => c.id).toList(),
                      labelBuilder: (id) => tCat(context, store.categories.firstWhere((c) => c.id == id).name),
                      groupBuilder: (id) {
                        final c = store.categories.firstWhere((c) => c.id == id);
                        if (c.parentId == null || c.parentId!.isEmpty) return '';
                        final parent = store.categories.where((p) => p.id == c.parentId);
                        return parent.isNotEmpty ? parent.first.name : '';
                      },
                      iconBuilder: (id) => _categoryIcon(store.categories.firstWhere((c) => c.id == id).icon),
                      colorBuilder: (id) => _hexToColor(store.categories.firstWhere((c) => c.id == id).color),
                      selectedId: _categoryId,
                    );
                    if (result != null) setState(() => _categoryId = result);
                  },
                ),
              ],
              if (_type == 'transfer') ...[
                _buildPicker(
                  label: context.tr('operations.to_account'),
                  value: store.accounts.where((a) => a.id == _toAccountId).map((a) => a.name).firstOrNull,
                  onTap: () async {
                    final result = await GroupedPickerSheet.show<String>(
                      context: context,
                      title: context.tr('operations.to_account'),
                      items: store.accounts.where((a) => a.id != _accountId).map((a) => a.id).toList(),
                      labelBuilder: (id) => store.accounts.firstWhere((a) => a.id == id).name,
                      groupBuilder: (id) => store.accounts.firstWhere((a) => a.id == id).currency,
                      subtitleBuilder: (id) {
                        final a = store.accounts.firstWhere((a) => a.id == id);
                        return '${a.balance.toStringAsFixed(2)} ${a.currency}';
                      },
                      iconBuilder: (id) => _accountIcon(store.accounts.firstWhere((a) => a.id == id).icon),
                      colorBuilder: (id) => _hexToColor(store.accounts.firstWhere((a) => a.id == id).color),
                      selectedId: _toAccountId,
                    );
                    if (result != null) setState(() => _toAccountId = result);
                  },
                ),
              ],
              const SizedBox(height: 16),
              AppInput(label: context.tr('operations.comment'), controller: _commentCtrl),
              const SizedBox(height: 16),
              AppInput(label: context.tr('operations.tags'), controller: _tagsCtrl),
              const SizedBox(height: 16),
              _buildPicker(
                label: context.tr('operations.date_time'),
                value: _formatDisplayDate(),
                onTap: () => _showDateTimePicker(),
              ),
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

  Widget _buildPicker({required String label, required String? value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
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
                    value ?? '',
                    style: TextStyle(fontSize: 15, color: value != null ? AppColors.textFor(context) : AppColors.textSecondaryFor(context)),
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

  IconData _accountIcon(String icon) {
    const map = {
      'cash': Icons.money, 'credit_card': Icons.credit_card,
      'savings': Icons.savings, 'account_balance': Icons.account_balance,
      'wallet': Icons.account_balance_wallet, 'payments': Icons.payments,
      'currency_ruble': Icons.currency_ruble, 'card_giftcard': Icons.card_giftcard,
    };
    return map[icon] ?? Icons.account_balance_wallet;
  }

  IconData _categoryIcon(String icon) {
    const map = {
      'food': Icons.restaurant, 'transport': Icons.directions_car,
      'housing': Icons.home, 'shopping': Icons.shopping_bag,
      'health': Icons.local_hospital, 'entertainment': Icons.sports_esports,
      'education': Icons.school, 'travel': Icons.flight,
      'salary': Icons.work, 'freelance': Icons.laptop, 'business': Icons.business,
      'gift': Icons.card_giftcard, 'car': Icons.directions_car,
      'sports': Icons.fitness_center, 'dining': Icons.restaurant,
      'utilities': Icons.bolt, 'internet': Icons.wifi,
      'clothing': Icons.checkroom, 'children': Icons.child_care,
      'pets': Icons.pets, 'taxes': Icons.receipt_long,
      'insurance': Icons.shield, 'invest': Icons.trending_up,
      'rent': Icons.home_work, 'other_income': Icons.add_circle,
      'other_expense': Icons.remove_circle, 'help': Icons.help_outline,
    };
    return map[icon] ?? Icons.category;
  }

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
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
              subtitle: t.amount > 0 ? Text('${t.type == 'income' ? '+' : '-'}${context.read<FinanceStore>().fmt(t.amount)}',
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
