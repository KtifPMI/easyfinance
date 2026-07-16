import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_button.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/goal.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});
  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
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
  bool _isLoading = false;
  bool _calculating = false;

  static const _saveCategories = {
    '1': 'Бытовая техника',
    '2': 'Дом',
    '0': 'Автомобиль',
    '3': 'Земельный участок',
    '4': 'Квартира',
    '5': 'Компьютер',
    '6': 'Лечение',
    '7': 'Мебель',
    '8': 'Мотоцикл',
    '9': 'Образование',
    '10': 'Отпуск',
    '11': 'Прочее',
    '12': 'Ремонт квартиры/дома',
    '13': 'Свадьба',
    '14': 'Финансовая подушка',
    '15': 'Шуба',
    '16': 'Электроника',
    '17': 'Ювелирные украшения',
  };

  static const _debtCategories = {
    'debt_mortgage': 'Долг по ипотеке',
    'debt_loan': 'Долг по кредитам',
    'debt_card': 'Долг по кредитным картам',
    'debt_other': 'Прочие долги',
  };

  Map<String, String> get _currentCategories {
    if (_type == 'save') return _saveCategories;
    if (_type == 'pay' || _type == 'mortgage') return _debtCategories;
    return {};
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _totalCtrl.dispose();
    _monthlyCtrl.dispose();
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
    return _parseSum(cleaned, 0);
  }

  int _parseSum(String s, int i) {
    double result = _parseProduct(s, i);
    while (i < s.length) {
      final c = s[i];
      if (c == '+') { i++; result += _parseProduct(s, i); }
      else if (c == '-') { i++; result -= _parseProduct(s, i); }
      else break;
    }
    return result.round();
  }

  double _parseProduct(String s, int i) {
    double result = _parseAtom(s, i);
    while (i < s.length) {
      final c = s[i];
      if (c == '*') { i++; result *= _parseAtom(s, i); }
      else if (c == '/') { i++; final d = _parseAtom(s, i); if (d != 0) result /= d; }
      else break;
    }
    return result;
  }

  double _parseAtom(String s, int i) {
    if (s[i] == '(') {
      i++;
      final val = _parseSum(s, i);
      if (i < s.length && s[i] == ')') i++;
      return val.toDouble();
    }
    final start = i;
    while (i < s.length && (s[i].isDigit || s[i] == '.')) i++;
    return double.tryParse(s.substring(start, i)) ?? 0;
  }

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
    final cats = _currentCategories;
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
    if (total <= 0 || monthly <= 0 || _firstPaymentDate == null) return;
    _calculating = true;
    final months = (total / monthly).ceil();
    final end = DateTime(_firstPaymentDate!.year, _firstPaymentDate!.month + months, _firstPaymentDate!.day);
    setState(() { _targetDate = end; });
    Future.microtask(() => _calculating = false);
  }

  void _recalcFromDate() {
    if (_calculating) return;
    final total = _parseAmount(_totalCtrl.text);
    if (total <= 0 || _firstPaymentDate == null || _targetDate == null) return;
    if (!_targetDate!.isAfter(_firstPaymentDate!)) return;
    _calculating = true;
    final months = (_targetDate!.year - _firstPaymentDate!.year) * 12 + (_targetDate!.month - _firstPaymentDate!.month);
    if (months <= 0) { _calculating = false; return; }
    final monthly = total / months;
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

  void _save() {
    if (!_canSave) return;
    final store = context.read<FinanceStore>();
    final total = _parseAmount(_totalCtrl.text);
    final monthly = _parseAmount(_monthlyCtrl.text);
    final endStr = _targetDate != null
        ? '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}'
        : '';
    final firstPaymentStr = _firstPaymentDate != null
        ? '${_firstPaymentDate!.year}-${_firstPaymentDate!.month.toString().padLeft(2, '0')}-${_firstPaymentDate!.day.toString().padLeft(2, '0')}'
        : '';

    store.addGoal(Goal(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      title: _titleCtrl.text.trim(),
      targetAmount: total,
      currentAmount: 0,
      deadline: endStr,
      isCompleted: _isCompleted,
      accountId: _selectedAccountIds.isNotEmpty ? _selectedAccountIds.first : null,
      currencyId: _currencyId,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final currencies = store.currencies;
    final accounts = store.accounts;
    final cats = _currentCategories;

    return ScreenScaffold(
      title: 'Финансовая цель',
      actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ],
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // Photo
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.monetization_on, size: 48, color: AppColors.primary),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                        child: Text('Изменить', style: TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('Открывается в новом окне', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
            const SizedBox(height: 24),

            // Блок 1
            Text('Основные параметры', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            const SizedBox(height: 12),

            _label('Хочу'),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: _decoration(),
              items: const [
                DropdownMenuItem(value: 'pay', child: Text('Выплатить')),
                DropdownMenuItem(value: 'save', child: Text('Накопить')),
                DropdownMenuItem(value: 'mortgage', child: Text('Долг по ипотеке')),
              ],
              onChanged: _onTypeChanged,
            ),
            const SizedBox(height: 12),

            if (_type != null) ...[
              _label('Категория'),
              DropdownButtonFormField<String>(
                value: _categoryId,
                decoration: _decoration(),
                items: cats.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: _onCategoryChanged,
              ),
              const SizedBox(height: 12),
            ],

            _label('Наименование'),
            TextFormField(
              controller: _titleCtrl,
              decoration: _decoration(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            _label('Статус'),
            Row(
              children: [
                Radio<String>(
                  value: 'normal',
                  groupValue: _status,
                  onChanged: (v) => setState(() => _status = v!),
                ),
                Text('Обычная'),
                const SizedBox(width: 24),
                Radio<String>(
                  value: 'favorite',
                  groupValue: _status,
                  onChanged: (v) => setState(() => _status = v!),
                ),
                Icon(Icons.star, size: 18, color: _status == 'favorite' ? AppColors.warning : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('Избранная'),
              ],
            ),
            const SizedBox(height: 24),

            // Блок 2
            Text('Финансовые привязки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            const SizedBox(height: 12),

            _label('Валюта цели'),
            DropdownButtonFormField<String>(
              value: _currencyId,
              decoration: _decoration(),
              items: currencies.map((c) {
                final id = c['id']?.toString() ?? '';
                final code = c['code']?.toString() ?? c['name']?.toString() ?? '';
                return DropdownMenuItem(value: id, child: Text(code));
              }).toList(),
              onChanged: (v) => setState(() => _currencyId = v),
            ),
            const SizedBox(height: 12),

            _label('Счета для погашения'),
            DropdownButtonFormField<String>(
              value: _selectedAccountIds.isNotEmpty ? _selectedAccountIds.first : null,
              decoration: _decoration(hint: 'Выберите счета привязанные к фин. цели'),
              items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedAccountIds = [v]);
              },
            ),
            const SizedBox(height: 4),
            Text('Я должен: 0 ${_currencyLabel(currencies)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            // Блок 3
            Text('Параметры выплат и расчеты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            const SizedBox(height: 12),

            _label('Всего к выплате'),
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
            Text('Пример: 12 + 33 * 45 <Enter>', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 12),

            _label('Дата первого взноса'),
            _datePicker(context, _firstPaymentDate, (d) {
              setState(() => _firstPaymentDate = d);
              _recalcFromMonthly();
            }),
            const SizedBox(height: 12),

            _label('Я могу выплачивать ежемесячно'),
            TextFormField(
              controller: _monthlyCtrl,
              decoration: _decoration(),
              keyboardType: TextInputType.number,
              onChanged: (_) => _recalcFromMonthly(),
            ),
            Text('Выводится усредненная сумма к выплате за 30 дней', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 8),

            Center(child: Text('или', style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic))),
            const SizedBox(height: 8),

            _label('Мне нужно выплатить к дате'),
            _datePicker(context, _targetDate, (d) {
              setState(() => _targetDate = d);
              _recalcFromDate();
            }),
            const SizedBox(height: 24),

            // Блок 4
            Text('Дополнительно', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            const SizedBox(height: 12),

            _label('Комментарии'),
            TextFormField(
              controller: _commentCtrl,
              decoration: _decoration(),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            CheckboxListTile(
              value: _isCompleted,
              onChanged: (v) => setState(() => _isCompleted = v ?? false),
              title: Text('Фин. цель выполнена'),
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
                    child: Text('Отмена', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppButton(
                    title: 'Сохранить',
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
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textFor(context))),
    );
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
                  : 'Выберите дату',
              style: TextStyle(color: selected != null ? AppColors.textFor(context) : AppColors.textSecondary),
            ),
            Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
