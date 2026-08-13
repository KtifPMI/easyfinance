import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/financial_event.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';
import '../../components/common/app_button.dart';
import '../../components/common/screen_scaffold.dart';
import 'package:easy_localization/easy_localization.dart';

class AddPlannedPaymentScreen extends StatefulWidget {
  final FinancialEvent? existing;
  final String? presetDate;
  const AddPlannedPaymentScreen({super.key, this.existing, this.presetDate});

  @override
  State<AddPlannedPaymentScreen> createState() => _AddPlannedPaymentScreenState();
}

class _AddPlannedPaymentScreenState extends State<AddPlannedPaymentScreen> {
  final _amountCtrl = TextEditingController();
  final _hourCtrl = TextEditingController();
  final _minuteCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  bool _commentError = false;

  String _type = 'expense';
  String _repeatOption = 'none'; // none | day | week | month | quarter | year
  String _limitMode = 'count'; // count | until
  String _repeatCount = '1';
  DateTime? _date;
  DateTime? _untilDate;
  String? _accountId;
  String? _categoryId;
  final List<bool> _weekdays = List.filled(7, false); // Пн..Вс

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _amountCtrl.text = e.amount > 0 ? e.amount.toStringAsFixed(2) : '';
      _type = e.type;
      _commentCtrl.text = e.comment ?? '';
      _tagsCtrl.text = e.tags ?? '';
      _accountId = e.accountId;
      _categoryId = e.categoryId;
      _date = e.dateStart != null
          ? DateTime.tryParse(e.dateStart!)
          : (e.date.isNotEmpty ? DateTime.tryParse(e.date) : null);
      _date ??= DateTime.now();
      _hourCtrl.text = '21';
      _minuteCtrl.text = '56';
      _repeatOption = _optionFromPeriod(e.repeatMode);
      if (e.repeatMode > 0) {
        if (e.dateEnd != null && e.dateEnd!.isNotEmpty) {
          _limitMode = 'until';
          _untilDate = DateTime.tryParse(e.dateEnd!);
        } else {
          _limitMode = 'count';
          _repeatCount = '1';
        }
      }
      if (e.weekDays != null && e.weekDays!.length == 7) {
        for (int i = 0; i < 7; i++) _weekdays[i] = e.weekDays![i] == '1';
      }
    } else {
      _date = widget.presetDate != null ? DateTime.tryParse(widget.presetDate!) : DateTime.now();
      _hourCtrl.text = '21';
      _minuteCtrl.text = '56';
      _weekdays[2] = true; // Ср по умолчанию
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _tagsCtrl.dispose();
    _commentCtrl.dispose();
    _repeatCountController?.dispose();
    super.dispose();
  }

  static String _optionFromPeriod(int period) {
    switch (period) {
      case 1:
        return 'day';
      case 7:
        return 'week';
      case 30:
        return 'month';
      case 90:
        return 'quarter';
      case 365:
        return 'year';
      default:
        return 'none';
    }
  }

  int get _period {
    switch (_repeatOption) {
      case 'day':
        return 1;
      case 'week':
        return 7;
      case 'month':
        return 30;
      case 'quarter':
        return 90;
      case 'year':
        return 365;
      default:
        return 0;
    }
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    return ScreenScaffold(
      title: context.tr('add_planned.title'),
      showLogo: false,
      actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ],
      child: _body(context, store),
    );
  }

  Widget _body(BuildContext context, FinanceStore store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Text(context.tr('add_planned.open_hint'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
        ),
        const SizedBox(height: 12),
        // Верхняя строка: сумма / дата / время
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _amountField(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _dateField(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _timeField(context),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _hint(context.tr('add_planned.amount_example')),
        _hint(context.tr('add_planned.time_hint')),
        const SizedBox(height: 12),
        // Счёт + тип операции
        Row(
          children: [
            Expanded(child: _accountField(context, store)),
            const SizedBox(width: 8),
            Expanded(child: _typeField(context)),
          ],
        ),
        const SizedBox(height: 12),
        _categoryField(context, store),
        const SizedBox(height: 12),
        _tagsField(context),
        const SizedBox(height: 12),
        _commentField(context),
        const SizedBox(height: 12),
        _repeatField(context),
        const SizedBox(height: 8),
        _repeatBlock(context),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.tr('planned_payments.cancel')),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppButton(
                title: context.tr('planned_payments.save'),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.textFor(context))),
      );

  Widget _amountField(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context.tr('planned_payments.amount') + ':'),
          Container(
            decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderFor(context))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                    onSubmitted: (_) => _evalAmount(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.calculate_outlined, size: 20, color: AppColors.textSecondaryFor(context)),
                  onPressed: _evalAmount,
                  tooltip: context.tr('add_planned.calculator'),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _dateField(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context.tr('planned_payments.date') + ':'),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderFor(context))),
              child: Text(_date != null ? _fmt(_date!) : '—', style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
            ),
          ),
        ],
      );

  Widget _timeField(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context.tr('add_planned.time') + ':'),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderFor(context))),
                  child: TextField(
                    controller: _hourCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 2,
                    decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(':', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderFor(context))),
                  child: TextField(
                    controller: _minuteCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 2,
                    decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _accountField(BuildContext context, FinanceStore store) {
    final accounts = store.accounts.where((a) => !a.isArchived).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context.tr('planned_payments.account') + ':'),
        DropdownButtonFormField<String>(
          value: _accountId,
          isExpanded: true,
          decoration: _dropdownDecoration(),
          hint: Text(context.tr('add_planned.account_hint')),
          items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _accountId = v),
        ),
      ],
    );
  }

  Widget _typeField(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context.tr('add_planned.type') + ':'),
          DropdownButtonFormField<String>(
            value: _type,
            isExpanded: true,
            decoration: _dropdownDecoration(),
            items: [
              DropdownMenuItem(value: 'expense', child: Text(context.tr('planned_payments.expense'))),
              DropdownMenuItem(value: 'income', child: Text(context.tr('planned_payments.income'))),
              DropdownMenuItem(value: 'transfer', child: Text(context.tr('planned_payments.transfer'))),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
        ],
      );

  Widget _categoryField(BuildContext context, FinanceStore store) {
    final cats = store.categories.where((c) => c.type == _type).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context.tr('planned_payments.category') + ':'),
        DropdownButtonFormField<String>(
          value: _categoryId,
          isExpanded: true,
          decoration: _dropdownDecoration(),
          hint: Text(context.tr('planned_payments.category_hint'), style: const TextStyle(fontWeight: FontWeight.w700)),
          items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() => _categoryId = v),
        ),
      ],
    );
  }

  Widget _tagsField(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context.tr('planned_payments.tags') + ':'),
          Container(
            decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderFor(context))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagsCtrl,
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  ),
                ),
                Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.textSecondaryFor(context))),
              ],
            ),
          ),
          _hint(context.tr('add_planned.name_example')),
        ],
      );

  Widget _commentField(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context.tr('planned_payments.name') + ' ' + context.tr('add_planned.name_required') + ':'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardFor(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _commentError ? AppColors.danger : AppColors.borderFor(context)),
            ),
            child: TextField(
              controller: _commentCtrl,
              maxLines: 3,
              minLines: 2,
              onChanged: (_) => setState(() => _commentError = false),
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
            ),
          ),
          if (_commentError)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(context.tr('add_planned.name_required_error'), style: TextStyle(fontSize: 12, color: AppColors.danger)),
            ),
        ],
      );

  InputDecoration _dropdownDecoration() => InputDecoration(
        filled: true,
        fillColor: AppColors.cardFor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.borderFor(context))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.borderFor(context))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _repeatField(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context.tr('add_planned.repeat') + ':'),
          DropdownButtonFormField<String>(
            value: _repeatOption,
            isExpanded: true,
            decoration: _dropdownDecoration(),
            items: [
              DropdownMenuItem(value: 'none', child: Text(context.tr('planned_payments.repeat_none'))),
              DropdownMenuItem(value: 'day', child: Text(context.tr('planned_payments.repeat_daily'))),
              DropdownMenuItem(value: 'week', child: Text(context.tr('planned_payments.repeat_weekly'))),
              DropdownMenuItem(value: 'month', child: Text(context.tr('planned_payments.repeat_monthly'))),
              DropdownMenuItem(value: 'quarter', child: Text(context.tr('planned_payments.repeat_quarterly'))),
              DropdownMenuItem(value: 'year', child: Text(context.tr('planned_payments.repeat_yearly'))),
            ],
            onChanged: (v) => setState(() => _repeatOption = v!),
          ),
        ],
      );

  Widget _repeatBlock(BuildContext context) {
    final children = <Widget>[
      if (_repeatOption == 'week') _weekdaySelector(context),
      _limitBlock(context),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _weekdaySelector(BuildContext context) {
    final labels = [
      context.tr('calendar.mon'),
      context.tr('calendar.tue'),
      context.tr('calendar.wed'),
      context.tr('calendar.thu'),
      context.tr('calendar.fri'),
      context.tr('calendar.sat'),
      context.tr('calendar.sun'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(7, (i) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: _weekdays[i],
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() => _weekdays[i] = v!),
              ),
              Text(labels[i], style: TextStyle(fontSize: 13, color: AppColors.textFor(context))),
            ],
          );
        }),
      ),
    );
  }

  Widget _limitBlock(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _radio('count', context.tr('add_planned.repeat_count'), _countField()),
          _radio('until', context.tr('add_planned.repeat_until'), _untilField()),
        ],
      );

  Widget _radio(String mode, String title, Widget trailing) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Radio<String>(
            value: mode,
            groupValue: _limitMode,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _limitMode = v!),
          ),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
          trailing,
        ],
      );

  Widget _countField() => SizedBox(
        width: 56,
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.borderFor(context))),
          child: TextField(
            controller: _repeatCountCtrl(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 3,
            decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
          ),
        ),
      );

  Widget _untilField() => InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _untilDate ?? (_date ?? DateTime.now()),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) setState(() => _untilDate = picked);
        },
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.borderFor(context))),
          child: Text(_untilDate != null ? _fmt(_untilDate!) : '', style: TextStyle(fontSize: 14, color: AppColors.textFor(context))),
        ),
      );

  // Отдельный контрлер для количества повторов (лениво)
  TextEditingController? _repeatCountController;
  TextEditingController _repeatCountCtrl() => _repeatCountController ??= TextEditingController(text: _repeatCount);

  void _evalAmount() {
    final expr = _amountCtrl.text.trim();
    if (expr.isEmpty) return;
    final value = _evaluate(expr.replaceAll(' ', ''));
    if (value != null) {
      setState(() => _amountCtrl.text = value.toStringAsFixed(2));
    }
  }

  double? _evaluate(String s) {
    try {
      int pos = 0;
      double parseTerm() {
        double parseFactor() {
          if (s[pos] == '(') {
            pos++;
            final v = parseTerm();
            pos++; // закрывающая скобка
            return v;
          }
          final start = pos;
          while (pos < s.length && (s.codeUnitAt(pos) >= 0x30 && s.codeUnitAt(pos) <= 0x39 || s[pos] == '.')) pos++;
          return double.parse(s.substring(start, pos));
        }

        var left = parseFactor();
        while (pos < s.length && (s[pos] == '*' || s[pos] == '/')) {
          final op = s[pos++];
          final right = parseFactor();
          left = op == '*' ? left * right : left / right;
        }
        return left;
      }

      var left = parseTerm();
      while (pos < s.length && (s[pos] == '+' || s[pos] == '-')) {
        final op = s[pos++];
        final right = parseTerm();
        left = op == '+' ? left + right : left - right;
      }
      return left;
    } catch (_) {
      return null;
    }
  }

  String? _buildWeekDays() {
    if (_repeatOption != 'week') return null;
    return _weekdays.map((b) => b ? '1' : '0').join('');
  }

  void _save() {
    final amount = (double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0).abs();
    if (amount <= 0) {
      Navigator.pop(context);
      return;
    }
    final comment = _commentCtrl.text.trim();
    if (widget.existing == null && comment.isEmpty) {
      setState(() => _commentError = true);
      return;
    }
    final period = _period;
    final dateStr = _date != null ? _fmt(_date!) : _fmt(DateTime.now());
    final dateStart = period > 0 ? dateStr : null;
    final dateEnd = (period > 0 && _limitMode == 'until') ? (_untilDate != null ? _fmt(_untilDate!) : null) : null;
    final weekDays = _buildWeekDays();
    final dayOfMonth = period == 30 ? (_date?.day) : null;

    final event = FinancialEvent(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: comment.isNotEmpty ? comment : (widget.existing?.title ?? ''),
      date: dateStr,
      amount: amount,
      type: _type,
      comment: comment.isNotEmpty ? comment : widget.existing?.comment,
      tags: _tagsCtrl.text.trim().isEmpty ? null : _tagsCtrl.text.trim(),
      repeatMode: period,
      accountId: _accountId,
      toAccountId: _type == 'transfer' ? _accountId : null,
      categoryId: _categoryId,
      dayOfMonth: dayOfMonth,
      isRecurring: period > 0,
      weekDays: weekDays,
      dateStart: dateStart,
      dateEnd: dateEnd,
      enabled: widget.existing?.enabled ?? true,
    );

    final store = context.read<PlannedPaymentStore>();
    if (widget.existing != null) {
      store.update(widget.existing!.id, event);
    } else {
      store.add(event);
    }
    Navigator.pop(context);
  }
}
