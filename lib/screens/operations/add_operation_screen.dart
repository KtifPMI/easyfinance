import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/calculator_input.dart';
import '../../components/common/grouped_picker_sheet.dart';
import '../../components/common/screen_scaffold.dart';
import '../../utils/translate_category.dart';
import '../../utils/category_icons.dart';
import '../../utils/format.dart';
import '../../theme/theme.dart';
import 'package:provider/provider.dart';
import '../../store/finance_store.dart';
import '../../models/operation.dart';
import '../../models/operation_template.dart';
import '../../services/currency_rate_service.dart';
import '../../utils/calc.dart';
import 'package:url_launcher/url_launcher.dart';

class AddOperationScreen extends StatefulWidget {
  final String? type;
  final String? operationId;
  final String? presetDate;
  final String? templateId;
  final String? copyFrom;

  const AddOperationScreen({super.key, this.type, this.operationId, this.presetDate, this.templateId, this.copyFrom});

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
  bool _commentExpanded = false;
  bool _saving = false;
  final List<String> _selectedTags = [];
  final _categoryKey = GlobalKey();

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
              Text(context.tr('operations.select_time'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeWheel(value: hour, onChanged: (v) => setSheetState(() => hour = v), isHour: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: AppColors.textFor(context))),
                  ),
                  _TimeWheel(value: minute, onChanged: (v) => setSheetState(() => minute = v), isHour: false),
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
                  child: Text(context.tr('common.ok'), style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
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
          if (t.tags != null) {
            _tagsCtrl.text = t.tags!;
            _selectedTags.addAll(t.tags!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
          }
          return;
        }
      }

      if (_isEditing) {
        final op = store.operations.where((o) => o.id == widget.operationId).firstOrNull;
        if (op != null) {
          if (op.date.isNotEmpty) {
            final d = DateTime.tryParse(op.date);
            if (d != null) _selectedDT = d;
          }
          _type = op.type;
          _amountCtrl.text = op.amount.toStringAsFixed(0);
          _accountId = op.accountId;
          _categoryId = op.categoryId;
          _toAccountId = op.toAccountId;
          if (op.comment != null) _commentCtrl.text = op.comment!;
          if (op.tags != null) {
            _tagsCtrl.text = op.tags!;
            _selectedTags.addAll(op.tags!.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty));
          }
        }
      } else if (widget.copyFrom != null) {
        final op = store.operations.where((o) => o.id == widget.copyFrom).firstOrNull;
        if (op != null) {
          if (op.date.isNotEmpty) {
            final d = DateTime.tryParse(op.date);
            if (d != null) _selectedDT = d;
          }
          _type = op.type;
          _amountCtrl.text = op.amount.toStringAsFixed(0);
          _accountId = op.accountId;
          _categoryId = op.categoryId;
          _toAccountId = op.toAccountId;
          if (op.comment != null) _commentCtrl.text = op.comment!;
          if (op.tags != null) {
            _tagsCtrl.text = op.tags!;
            _selectedTags.addAll(op.tags!.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty));
          }
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

  String _combinedTags() {
    return {
      ..._selectedTags,
      ..._tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty),
    }.join(', ');
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
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
        tags: _combinedTags().isNotEmpty ? _combinedTags() : null,
        clientId: clientId,
      );

      if (_isEditing) {
        await store.updateOperation(op);
      } else {
        await store.addOperation(op);
      }
      if (!mounted) return;
      if (store.error != null) {
        if (store.error == 'LIMIT') {
          _showLimitDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!), backgroundColor: Colors.red));
        }
        return;
      }
      _showSavedDialog(context, store, op);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSavedDialog(BuildContext context, FinanceStore store, Operation op) {
    final catId = op.categoryId;
    final budget = catId != null ? store.budgets.where((b) => b.categoryId == catId && !b.isDeleted).firstOrNull : null;
    final now = DateTime.now();
    final catSpend = catId != null
        ? store.operations.where((o) => !o.isDeleted && o.type == 'expense' && o.categoryId == catId && store.isInMonth(o.date, now)).fold(0.0, (s, o) => s + o.amount)
        : 0.0;
    final totalBudgetRemaining = store.budgets.where((b) => !b.isDeleted).fold(0.0, (s, b) => s + (b.limit - b.spent));
    final account = store.getAccount(op.accountId);
    final accountRemaining = account != null ? store.accountActualBalance(account) : 0.0;

    final bool overBudget = budget != null && budget.spent > budget.limit;
    final String tip;
    if (overBudget) {
      tip = 'Превышен лимит бюджета категории на ${store.fmt(budget.spent - budget.limit)}.';
    } else if (budget != null) {
      tip = 'По бюджету категории сэкономлено ${store.fmt(budget.limit - budget.spent)}.';
    } else {
      tip = 'Категория без бюджета: за месяц потрачено ${store.fmt(catSpend)}.';
    }

    final children = <Widget>[
      Text('${context.tr('operations.amount')}: ${store.fmt(op.amount)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      if (catId != null)
        Text(tCat(context, store.getCategory(catId)?.name ?? ''), style: TextStyle(fontSize: 15)),
      const SizedBox(height: 12),
      Text('add_operation.by_data'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
      const SizedBox(height: 4),
      Text('add_operation.category_spend'.tr(namedArgs: {'amount': store.fmt(catSpend)}), style: TextStyle(fontSize: 15)),
      if (budget != null)
        Text('add_operation.category_budget_remaining'.tr(namedArgs: {'amount': store.fmt((budget.limit - budget.spent).clamp(0, double.infinity))}), style: TextStyle(fontSize: 15)),
      Text('add_operation.total_budget_remaining'.tr(namedArgs: {'amount': store.fmt(totalBudgetRemaining.clamp(0, double.infinity))}), style: TextStyle(fontSize: 15)),
      Text('add_operation.account_remaining'.tr(namedArgs: {'amount': store.fmt(accountRemaining)}), style: TextStyle(fontSize: 15)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (overBudget ? AppColors.expense : AppColors.success).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(tip, style: TextStyle(fontSize: 13, color: overBudget ? AppColors.expense : AppColors.success)),
      ),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('operations.saved')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetForAnother();
            },
            child: Text(context.tr('operations.more')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/operations', arguments: {'sort': 'date_desc'});
            },
            child: Text('add_operation.recent'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              store.addTemplate(OperationTemplate(
                id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
                name: _templateName(store, op),
                type: op.type,
                amount: op.amount,
                accountId: op.accountId,
                categoryId: op.categoryId,
                toAccountId: op.toAccountId,
                comment: op.comment,
                tags: op.tags,
              ));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('templates.new'))));
              }
            },
            child: Text(context.tr('templates.save_as_template')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/operations');
            },
            child: Text(context.tr('tab.operations')),
          ),
        ],
      ),
    );
  }

  String _templateName(FinanceStore store, Operation op) {
    final cat = op.categoryId != null ? store.getCategory(op.categoryId) : null;
    return cat != null
        ? tCat(context, cat.name)
        : (op.comment?.isNotEmpty == true ? op.comment! : context.tr('templates.new'));
  }

  void _resetForAnother() {
    setState(() {
      _amountCtrl.clear();
      _commentCtrl.clear();
      _tagsCtrl.clear();
      _selectedTags.clear();
    });
  }

  void _showLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('operations.limit_reached')),
        content: Text(context.tr('operations.limit_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse('https://easyfinance.ru/my/shop');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('https://easyfinance.ru/my/shop'), duration: const Duration(seconds: 5)),
                );
              }
            },
            child: Text(context.tr('operations.upgrade_tariff'), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
          title: _isEditing ? context.tr('operations.edit') : widget.copyFrom != null ? context.tr('operations.copy') : context.tr('operations.add'),
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
              Row(
                children: [
                  _typeBtn('expense', Icons.remove_circle_outline, AppColors.expense, context.tr('operations.type_expense')),
                  const SizedBox(width: 8),
                  _typeBtn('income', Icons.add_circle_outline, AppColors.success, context.tr('operations.type_income')),
                  const SizedBox(width: 8),
                  _typeBtn('transfer', Icons.swap_horiz, AppColors.transfer, context.tr('operations.type_transfer')),
                ],
              ),
              const SizedBox(height: 20),
              CalculatorInput(controller: _amountCtrl, label: context.tr('operations.amount')),
              const SizedBox(height: 16),
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
                        Text(context.tr('operations.use_template'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
                  if (result != null) {
                    setState(() => _accountId = result);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_categoryKey.currentContext != null) {
                        Scrollable.ensureVisible(_categoryKey.currentContext!, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_type != 'transfer') ...[
                Container(key: _categoryKey, child: _buildPicker(
                  label: context.tr('operations.category'),
                  value: store.categories.where((c) => c.id == _categoryId).map((c) => tCat(context, c.name)).firstOrNull,
                  onTap: () async {
                    final cats = store.categories.where((c) => c.type == _type).toList();
                    final counts = <String, int>{};
                    for (final op in store.operations.where((o) => o.type == _type && !o.isDeleted)) {
                      if (op.categoryId != null) counts[op.categoryId!] = (counts[op.categoryId!] ?? 0) + 1;
                    }
                    cats.sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
                    final frequentIds = cats.take(5).where((c) => (counts[c.id] ?? 0) > 0).map((c) => c.id).toSet();
                    final result = await GroupedPickerSheet.show<String>(
                      context: context,
                      title: context.tr('operations.category'),
                      items: cats.map((c) => c.id).toList(),
                      labelBuilder: (id) => tCat(context, store.categories.firstWhere((c) => c.id == id).name),
                      orderedGroups: [context.tr('categories.popular'), context.tr('categories.main')],
                      groupBuilder: (id) {
                        if (frequentIds.contains(id)) return context.tr('categories.popular');
                        final c = store.categories.firstWhere((c) => c.id == id);
                        if (c.parentId == null || c.parentId!.isEmpty || c.parentId == '0') return context.tr('categories.main');
                        final parent = store.categories.where((p) => p.id == c.parentId);
                        return parent.isNotEmpty ? parent.first.name : context.tr('categories.main');
                      },
                      iconBuilder: (id) => categoryIconFor(store.categories.firstWhere((c) => c.id == id), allCategories: store.categories),
                      colorBuilder: (id) => _type == 'income' ? AppColors.income : AppColors.expense,
                      selectedId: _categoryId,
                    );
                    if (result != null) setState(() => _categoryId = result);
                  },
                )),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(context.tr('operations.comment'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context)))),
                      GestureDetector(
                        onTap: () => setState(() => _commentExpanded = !_commentExpanded),
                        child: Icon(_commentExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.textSecondaryFor(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: _commentExpanded ? 5 : 1,
                    style: TextStyle(fontSize: 16, color: AppColors.textFor(context)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.cardFor(context),
                      hintText: context.tr('operations.comment_hint'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderFor(context))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderFor(context))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTagSelector(context, store),
              const SizedBox(height: 16),
              _buildPicker(
                label: context.tr('operations.date_time'),
                value: _formatDisplayDate(),
                onTap: () => _showDateTimePicker(),
              ),
              const SizedBox(height: 24),
              if (_type == 'expense' && _categoryId != null) _buildBudgetWarning(context, store),
              AppButton(title: context.tr('operations.save'), onPressed: _saving ? null : _save, loading: _saving),
           ],
          ),
        );
      },
    );
  }

  Widget _typeBtn(String type, IconData icon, Color color, String label) {
    final active = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color : AppColors.cardFor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? color : AppColors.borderFor(context)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: active ? Colors.white : color),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: active ? Colors.white : AppColors.textFor(context),
              )),
            ],
          ),
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
          Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
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
                    style: TextStyle(fontSize: 16, color: value != null ? AppColors.textFor(context) : AppColors.textSecondaryFor(context)),
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
              child: Text(context.tr('operations.use_template'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            ),
            ...store.templates.map((t) => ListTile(
              leading: Icon(
                t.type == 'income' ? Icons.add_circle_outline : t.type == 'transfer' ? Icons.swap_horiz : Icons.remove_circle_outline,
                color: t.type == 'income' ? AppColors.income : t.type == 'transfer' ? AppColors.transfer : AppColors.expense,
              ),
              title: Text(t.name),
              subtitle: t.amount > 0 ? Text('${t.type == 'income' ? '+' : '-'}${context.read<FinanceStore>().fmt(t.amount)}',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))) : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _type = t.type;
                  if (t.amount > 0) _amountCtrl.text = t.amount.toStringAsFixed(0);
                  _accountId = t.accountId;
                  _categoryId = t.categoryId;
                  _toAccountId = t.toAccountId;
                  if (t.comment != null) _commentCtrl.text = t.comment!;
                  if (t.tags != null) {
                    _tagsCtrl.text = t.tags!;
                    _selectedTags.addAll(t.tags!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
                  }
                });
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTagSelector(BuildContext context, FinanceStore store) {
    final availableTags = <String>{
      ...store.tags.map((t) => t.name),
      for (final op in store.operations) ...store.getTagsForOperation(op),
    }.toList();
    final customTags = _tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    final allTags = <String>{
      ..._selectedTags,
      ...customTags,
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('operations.tags'), style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
        const SizedBox(height: 8),
        if (availableTags.isNotEmpty || allTags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ...allTags.map((t) => Chip(
                label: Text('#$t', style: TextStyle(fontSize: 13, color: Colors.white)),
                backgroundColor: AppColors.primary,
                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                onDeleted: () {
                  setState(() {
                    _selectedTags.remove(t);
                    final ctags = _tagsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                    ctags.remove(t);
                    _tagsCtrl.text = ctags.join(', ');
                  });
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              )),
            ],
          ),
        if (availableTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: null,
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.cardFor(context),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              hintText: context.tr('tags.add_tag'),
            ),
            items: availableTags.where((t) => !allTags.contains(t)).map((t) => DropdownMenuItem(value: t, child: Text('#$t', style: TextStyle(fontSize: 15)))).toList(),
            onChanged: (v) {
              if (v != null && !_selectedTags.contains(v)) {
                setState(() => _selectedTags.add(v));
              }
            },
            isExpanded: true,
          ),
        ],
        const SizedBox(height: 4),
        TextField(
          controller: _tagsCtrl,
          style: TextStyle(fontSize: 14, color: AppColors.textFor(context)),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.cardFor(context),
            hintText: context.tr('tags.custom_tag_hint'),
            hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context).withValues(alpha: 0.6)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderFor(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderFor(context))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetWarning(BuildContext context, FinanceStore store) {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return const SizedBox.shrink();
    final budget = store.budgets.where((b) => b.categoryId == _categoryId && !b.isDeleted).firstOrNull;
    if (budget == null) return const SizedBox.shrink();
    final newSpent = budget.spent + amount;
    final forecastPct = getBudgetForecastPercent(budget.copyWith(spent: newSpent));
    if (forecastPct <= 90) return const SizedBox.shrink();

    final cat = store.getCategory(_categoryId!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: forecastPct > 100 ? AppColors.danger.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: forecastPct > 100 ? AppColors.danger : AppColors.warning, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: forecastPct > 100 ? AppColors.danger : AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('budget.warning_fmt', namedArgs: {
                  'name': cat != null ? tCat(context, cat.name) : '',
                  'pct': '${forecastPct.round()}',
                }),
                style: TextStyle(fontSize: 13, color: AppColors.textFor(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeWheel extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final bool isHour;

  const _TimeWheel({required this.value, required this.onChanged, required this.isHour});

  @override
  State<_TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<_TimeWheel> {
  late final FixedExtentScrollController _controller;
  int _lastValue = 0;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.value;
    _controller = FixedExtentScrollController(initialItem: widget.value);
  }

  @override
  void didUpdateWidget(covariant _TimeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _lastValue && _controller.hasClients) {
      _lastValue = widget.value;
      _controller.animateToItem(
        widget.value,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.isHour ? 24 : 60;
    return SizedBox(
      width: 64,
      height: 140,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: 36,
        diameterRatio: 1.8,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          _lastValue = index;
          widget.onChanged(index);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) {
            final selected = index == widget.value;
            return Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.textSecondaryFor(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
