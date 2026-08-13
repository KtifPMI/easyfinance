import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/common/app_button.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/goal.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class AddGoalScreen extends StatefulWidget {
  final String? goalId;
  const AddGoalScreen({super.key, this.goalId});
  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  final _initialCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _totalFocus = FocusNode();

  String? _type;
  String? _categoryId;
  String _categoryName = '';
  String _status = 'normal';
  String? _currencyId;
  List<String> _selectedAccountIds = [];
  DateTime? _firstPaymentDate;
  DateTime? _targetDate;
  bool _isCompleted = false;
  bool _calculating = false;

  Map<String, String> _saveCategories(BuildContext context) => {
    '1': context.tr('goal_cat.appliances'),
    '2': context.tr('goal_cat.home'),
    '0': context.tr('goal_cat.auto'),
    '3': context.tr('goal_cat.land'),
    '4': context.tr('goal_cat.apartment'),
    '5': context.tr('goal_cat.computer'),
    '6': context.tr('goal_cat.medical'),
    '7': context.tr('goal_cat.furniture'),
    '8': context.tr('goal_cat.motorcycle'),
    '9': context.tr('goal_cat.education'),
    '10': context.tr('goal_cat.vacation'),
    '11': context.tr('goal_cat.other'),
    '12': context.tr('goal_cat.renovation'),
    '13': context.tr('goal_cat.wedding'),
    '14': context.tr('goal_cat.emergency_fund'),
    '15': context.tr('goal_cat.fur_coat'),
    '16': context.tr('goal_cat.electronics'),
    '17': context.tr('goal_cat.jewelry'),
  };

  Map<String, String> _debtCategories(BuildContext context) => {
    'debt_loan': context.tr('goal_cat.debt_loan'),
    'debt_card': context.tr('goal_cat.debt_card'),
    'debt_other': context.tr('goal_cat.debt_other'),
  };

  Map<String, String> _currentCategories(BuildContext context) {
    if (_type == 'save') return _saveCategories(context);
    if (_type == 'pay') return _debtCategories(context);
    return {};
  }

  bool get _isEditing => widget.goalId != null;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      if (_isEditing) {
        final store = context.read<FinanceStore>();
        final g = store.goals.where((g) => g.id == widget.goalId).firstOrNull;
        if (g != null) {
          _titleCtrl.text = g.title;
          _totalCtrl.text = g.targetAmount > 0 ? g.targetAmount.toStringAsFixed(0) : '';
          _initialCtrl.text = g.currentAmount > 0 ? g.currentAmount.toStringAsFixed(0) : '';
          if (g.monthlyRecommendation != null && g.monthlyRecommendation! > 0) {
            _monthlyCtrl.text = g.monthlyRecommendation!.toStringAsFixed(0);
          }
          _type = g.accountId != null ? 'save' : 'pay';
          _currencyId = g.currencyId;
          if (g.startDate.isNotEmpty) {
            _firstPaymentDate = DateTime.tryParse(g.startDate);
          }
          if (g.deadline.isNotEmpty) {
            _targetDate = DateTime.tryParse(g.deadline);
          }
          _isCompleted = g.isCompleted;
          if (g.accountId != null) _selectedAccountIds = [g.accountId!];
          final cats = _currentCategories(context);
          if (cats.isNotEmpty) {
            _categoryId = cats.keys.first;
            _categoryName = cats[_categoryId]!;
            SharedPreferences.getInstance().then((p) {
              final saved = p.getString('goal_cat_${widget.goalId}');
              if (saved != null && cats.containsKey(saved) && mounted) {
                setState(() {
                  _categoryId = saved;
                  _categoryName = cats[saved]!;
                });
              }
            });
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _totalCtrl.dispose();
    _monthlyCtrl.dispose();
    _initialCtrl.dispose();
    _commentCtrl.dispose();
    _totalFocus.dispose();
    super.dispose();
  }

  double _parseAmount(String raw) {
    return double.tryParse(raw.replaceAll(',', '.').trim()) ?? 0;
  }

  double _safeEval(String expr) {
    final cleaned = expr.replaceAll(' ', '');
    if (cleaned.isEmpty) return 0;
    _evalPos = 0;
    return _parseGoalExpr(cleaned);
  }

  double _parseGoalTerm(String s) {
    double result = _parseGoalFactor(s);
    while (_evalPos < s.length) {
      final c = s[_evalPos];
      if (c == '*') { _evalPos++; result *= _parseGoalFactor(s); }
      else if (c == '/') { _evalPos++; final d = _parseGoalFactor(s); if (d != 0) result /= d; }
      else { break; }
    }
    return result;
  }

  double _parseGoalFactor(String s) {
    if (s[_evalPos] == '(') {
      _evalPos++;
      final val = _parseGoalExpr(s);
      if (_evalPos < s.length && s[_evalPos] == ')') _evalPos++;
      return val;
    }
    final start = _evalPos;
    while (_evalPos < s.length && (int.tryParse(s[_evalPos]) != null || s[_evalPos] == '.')) { _evalPos++; }
    return double.tryParse(s.substring(start, _evalPos)) ?? 0;
  }

  double _parseGoalExpr(String s) {
    double result = _parseGoalTerm(s);
    while (_evalPos < s.length) {
      final c = s[_evalPos];
      if (c == '+') { _evalPos++; result += _parseGoalTerm(s); }
      else if (c == '-') { _evalPos++; result -= _parseGoalTerm(s); }
      else { break; }
    }
    return result;
  }

  int _evalPos = 0;

  void _onTypeChanged(String? v) {
    setState(() {
      _type = v;
      _categoryId = null;
      _categoryName = '';
      _titleCtrl.clear();
    });
  }

  void _onCategoryChanged(String? id) {
    if (id == null) return;
    final cats = _currentCategories(context);
    setState(() {
      _categoryId = id;
      _categoryName = cats[id] ?? '';
      if (_titleCtrl.text.isEmpty || _titleCtrl.text == _categoryName) {
        _titleCtrl.text = _categoryName;
      }
    });
  }

  void _recalcFromMonthly() {
    if (_calculating) return;
    final total = _parseAmount(_totalCtrl.text);
    final monthly = _parseAmount(_monthlyCtrl.text);
    final initial = _parseAmount(_initialCtrl.text);
    if (total <= 0 || monthly <= 0 || _firstPaymentDate == null) return;
    _calculating = true;
    final remaining = (total - initial).clamp(0, total);
    if (remaining <= 0) {
      _targetDate = _firstPaymentDate;
      _calculating = false;
      setState(() {});
      return;
    }
    final months = (remaining / monthly).ceil();
    final end = DateTime(_firstPaymentDate!.year, _firstPaymentDate!.month + months, _firstPaymentDate!.day);
    setState(() { _targetDate = end; });
    Future.microtask(() => _calculating = false);
  }

  void _recalcFromDate() {
    if (_calculating) return;
    final total = _parseAmount(_totalCtrl.text);
    final initial = _parseAmount(_initialCtrl.text);
    if (total <= 0 || _firstPaymentDate == null || _targetDate == null) return;
    if (!_targetDate!.isAfter(_firstPaymentDate!)) return;
    _calculating = true;
    final remaining = (total - initial).clamp(0, total);
    if (remaining <= 0) {
      _monthlyCtrl.text = '0';
      _calculating = false;
      setState(() {});
      return;
    }
    final months = (_targetDate!.year - _firstPaymentDate!.year) * 12 + (_targetDate!.month - _firstPaymentDate!.month);
    if (months <= 0) { _calculating = false; return; }
    final monthly = remaining / months;
    _monthlyCtrl.text = monthly.toStringAsFixed(0);
    setState(() {});
    Future.microtask(() => _calculating = false);
  }

  bool get _canSave {
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (_type == null) return false;
    if (_categoryId == null) return false;
    if (_currencyId == null) return false;
    final total = _parseAmount(_totalCtrl.text);
    return total > 0;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final store = context.read<FinanceStore>();
    final total = _parseAmount(_totalCtrl.text);
    final current = _parseAmount(_initialCtrl.text);
    final startStr = _firstPaymentDate != null
        ? '${_firstPaymentDate!.year}-${_firstPaymentDate!.month.toString().padLeft(2, '0')}-${_firstPaymentDate!.day.toString().padLeft(2, '0')}'
        : '';
    final endStr = _targetDate != null
        ? '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}'
        : '';
    if (_isEditing) {
      await store.updateGoal(
        widget.goalId!,
        title: _titleCtrl.text.trim(),
        targetAmount: total,
        currentAmount: current,
        isCompleted: _isCompleted,
        deadline: endStr,
        startDate: startStr,
        accountId: _selectedAccountIds.isNotEmpty ? _selectedAccountIds.first : null,
        currencyId: _currencyId,
      );
    } else {
      final newId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      await store.addGoal(Goal(
        id: newId,
        title: _titleCtrl.text.trim(),
        targetAmount: total,
        currentAmount: current,
        startDate: startStr,
        deadline: endStr,
        isCompleted: _isCompleted,
        accountId: _selectedAccountIds.isNotEmpty ? _selectedAccountIds.first : null,
        currencyId: _currencyId,
      ));
      if (_categoryId != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('goal_cat_$newId', _categoryId!);
      }
    }
    if (!mounted) return;
    if (store.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!), backgroundColor: AppColors.danger));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final currencies = store.currencies;
    final accounts = store.accounts;
    final cats = _currentCategories(context);

    return ScreenScaffold(
      title: context.tr('goals.goal_type'),
      showLogo: false,
      actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ],
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // Photo
            Center(
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.monetization_on, size: 48, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 24),

            // Блок 1
            Text(context.tr('goals.main_params'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            const SizedBox(height: 12),

            _label(context.tr('goals.want_to')),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: _decoration(),
              items: [
                DropdownMenuItem(value: 'pay', child: Text(context.tr('goals.type_pay'))),
                DropdownMenuItem(value: 'save', child: Text(context.tr('goals.type_save'))),
              ],
              onChanged: _onTypeChanged,
            ),
            const SizedBox(height: 12),

            if (_type != null) ...[
              _label(context.tr('goals.category')),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: _decoration(),
                items: cats.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: _onCategoryChanged,
              ),
              const SizedBox(height: 12),
            ],

            _label(context.tr('goals.goal_name')),
            TextFormField(
              controller: _titleCtrl,
              decoration: _decoration(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            _label(context.tr('goals.status')),
            RadioGroup<String>(
              groupValue: _status,
              onChanged: (v) => setState(() => _status = v!),
              child: Row(
                children: [
                  Radio<String>(value: 'normal'),
                  Text(context.tr('goals.status_normal')),
                  const SizedBox(width: 24),
                  Radio<String>(value: 'favorite'),
                  Icon(Icons.star, size: 18, color: _status == 'favorite' ? AppColors.warning : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(context.tr('goals.status_favorite')),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Блок 2
            Text(context.tr('goals.financial_links'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            const SizedBox(height: 12),

            _label(context.tr('goals.goal_currency')),
            DropdownButtonFormField<String>(
              initialValue: _currencyId,
              decoration: _decoration(),
              items: currencies.map((c) {
                final id = c['id']?.toString() ?? '';
                final code = c['code']?.toString() ?? c['name']?.toString() ?? '';
                return DropdownMenuItem(value: id, child: Text(code));
              }).toList(),
              onChanged: (v) => setState(() => _currencyId = v),
            ),
            const SizedBox(height: 12),

            _label(_flabel(context, 'goals.accounts_for_payment', 'goals.save_accounts')),
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountIds.isNotEmpty ? _selectedAccountIds.first : null,
              decoration: _decoration(hint: context.tr('goals.select_accounts_hint')),
              items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedAccountIds = [v]);
              },
            ),
            const SizedBox(height: 4),
            if (_type == 'pay')
              Text(context.tr('goals.debt_label', namedArgs: {'currency': _currencyLabel(currencies)}), style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            // Блок 3
            Text(context.tr('goals.payment_params'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            const SizedBox(height: 12),

            _label(_flabel(context, 'goals.total_to_pay', 'goals.save_goal_amount')),
            TextFormField(
              controller: _totalCtrl,
              focusNode: _totalFocus,
              decoration: _decoration(suffix: Icon(Icons.calculate, size: 20, color: AppColors.primary)),
              keyboardType: TextInputType.text,
              onFieldSubmitted: (v) {
                if (v.contains('+') || v.contains('-') || v.contains('*') || v.contains('/')) {
                  final result = _safeEval(v);
                  _totalCtrl.text = result.toStringAsFixed(2);
                  _totalCtrl.selection = TextSelection.collapsed(offset: _totalCtrl.text.length);
                }
              },
              onChanged: (_) => setState(() {}),
            ),
            Text(context.tr('goals.calc_hint'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),

            _label(_flabel(context, 'goals.first_payment_date', 'goals.save_first_date')),
            _datePicker(context, _firstPaymentDate, (d) {
              setState(() => _firstPaymentDate = d);
              _recalcFromMonthly();
            }),
            const SizedBox(height: 12),

            _label(_flabel(context, 'goals.monthly_payment', 'goals.save_monthly')),
            TextFormField(
              controller: _monthlyCtrl,
              decoration: _decoration(),
              keyboardType: TextInputType.number,
              onChanged: (_) => _recalcFromMonthly(),
            ),
            Text(_flabel(context, 'goals.monthly_hint', 'goals.save_monthly_hint'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),

            Center(child: Text(context.tr('goals.or'), style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic))),
            const SizedBox(height: 8),

            _label(_flabel(context, 'goals.target_date', 'goals.save_target_date')),
            _datePicker(context, _targetDate, (d) {
              setState(() => _targetDate = d);
              _recalcFromDate();
            }),
            const SizedBox(height: 24),

            // Блок 4
            Text(context.tr('goals.additional'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            const SizedBox(height: 12),

            _label(context.tr('goals.comments')),
            TextFormField(
              controller: _commentCtrl,
              decoration: _decoration(),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            CheckboxListTile(
              value: _isCompleted,
              onChanged: (v) => setState(() => _isCompleted = v ?? false),
              title: Text(context.tr('goals.goal_completed')),
              secondary: Icon(Icons.emoji_events, color: _isCompleted ? AppColors.warning : AppColors.textSecondary),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: Text(context.tr('goals.cancel'), style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(
                    title: context.tr('goals.save'),
                    onPressed: _canSave ? _save : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _currencyLabel(List<Map<String, dynamic>> currencies) {
    if (_currencyId == null) return '₽';
    final c = currencies.where((c) => c['id']?.toString() == _currencyId).firstOrNull;
    return c?['code']?.toString() ?? c?['name']?.toString() ?? '₽';
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textFor(context))),
    );
  }

  String _flabel(BuildContext context, String payKey, String saveKey) {
    return context.tr(_type == 'save' ? saveKey : payKey);
  }

  InputDecoration _decoration({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      isDense: true,
    );
  }

  Widget _datePicker(BuildContext context, DateTime? selected, ValueChanged<DateTime> onPicked) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: selected ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        );
        if (d != null) onPicked(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selected != null
                  ? '${selected.day.toString().padLeft(2, '0')}.${selected.month.toString().padLeft(2, '0')}.${selected.year}'
                  : context.tr('goals.choose_date'),
              style: TextStyle(color: selected != null ? AppColors.textFor(context) : AppColors.textSecondary),
            ),
            Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
