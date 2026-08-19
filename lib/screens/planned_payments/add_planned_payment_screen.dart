import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/financial_event.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_card.dart';
import '../../components/common/calculator_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/common/grouped_picker_sheet.dart';
import '../../utils/category_icons.dart';
import '../../utils/translate_category.dart';
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
  String? _toAccountId;
  final List<bool> _weekdays = List.filled(7, false); // Пн..Вс

  @override
  void initState() {
    super.initState();
    _hourCtrl.text = '21';
    _minuteCtrl.text = '56';
    final e = widget.existing;
    if (e != null) {
      _amountCtrl.text = e.amount > 0 ? e.amount.toStringAsFixed(2) : '';
      _type = e.type;
      _commentCtrl.text = e.comment ?? '';
      _accountId = e.accountId;
      _categoryId = e.categoryId;
      _toAccountId = e.toAccountId;
      _date = e.dateStart != null
          ? DateTime.tryParse(e.dateStart!)
          : (e.date.isNotEmpty ? DateTime.tryParse(e.date) : null);
      _date ??= DateTime.now();
      if (e.time != null && e.time!.length >= 5) {
        _hourCtrl.text = e.time!.substring(0, 2);
        _minuteCtrl.text = e.time!.substring(3, 5);
      }
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
      _weekdays[2] = true; // Ср по умолчанию
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
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
        const SizedBox(height: 12),
        _section(
          context.tr('add_planned.section_main'),
          [
            _typeButtons(context),
            const SizedBox(height: 12),
            CalculatorInput(controller: _amountCtrl, label: context.tr('add_planned.amount')),
            const SizedBox(height: 12),
            _accountField(context, store),
            if (_type != 'transfer') ...[
              const SizedBox(height: 12),
              _categoryField(context, store),
            ],
            if (_type == 'transfer') ...[
              const SizedBox(height: 12),
              _toAccountField(context, store),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _section(
          context.tr('add_planned.section_schedule'),
          [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _dateField(context)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _timeField(context)),
              ],
            ),
            const SizedBox(height: 12),
            _repeatField(context),
            const SizedBox(height: 8),
            _repeatBlock(context),
          ],
        ),
        const SizedBox(height: 12),
        _section(
          context.tr('add_planned.section_extra'),
          [
            _commentField(context),
          ],
        ),
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

  Widget _section(String title, List<Widget> children) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.textFor(context))),
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
          InkWell(
            onTap: () => _showTimePicker(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderFor(context))),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_hourCtrl.text.padLeft(2, '0')}:${_minuteCtrl.text.padLeft(2, '0')}',
                      style: TextStyle(fontSize: 16, color: AppColors.textFor(context)),
                    ),
                  ),
                  Icon(Icons.access_time, size: 20, color: AppColors.textSecondaryFor(context)),
                ],
              ),
            ),
          ),
        ],
      );

  void _showTimePicker(BuildContext context) async {
    int hour = int.tryParse(_hourCtrl.text) ?? 0;
    int minute = int.tryParse(_minuteCtrl.text) ?? 0;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('add_planned.time'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
                    setState(() {
                      _hourCtrl.text = hour.toString();
                      _minuteCtrl.text = minute.toString();
                    });
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

  Widget _accountField(BuildContext context, FinanceStore store) {
    final accounts = store.accounts.where((a) => !a.isArchived).toList();
    final selected = accounts.where((a) => a.id == _accountId).firstOrNull;
    return _buildPicker(
      label: context.tr('planned_payments.account'),
      value: selected?.name,
      onTap: () async {
        final result = await GroupedPickerSheet.show<String>(
          context: context,
          title: context.tr('planned_payments.account'),
          items: accounts.map((a) => a.id).toList(),
          labelBuilder: (id) => accounts.firstWhere((a) => a.id == id).name,
          groupBuilder: (id) => accounts.firstWhere((a) => a.id == id).currency,
          subtitleBuilder: (id) {
            final a = accounts.firstWhere((a) => a.id == id);
            return '${a.balance.toStringAsFixed(2)} ${a.currency}';
          },
          iconBuilder: (id) => _accountIcon(accounts.firstWhere((a) => a.id == id).icon),
          colorBuilder: (id) => _hexToColor(accounts.firstWhere((a) => a.id == id).color),
          selectedId: _accountId,
        );
        if (result != null) setState(() => _accountId = result);
      },
    );
  }

  Widget _typeButtons(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context.tr('add_planned.type')),
          const SizedBox(height: 8),
          Row(
            children: [
              _typeBtn('expense', Icons.trending_down, AppColors.expense, context.tr('planned_payments.expense')),
              const SizedBox(width: 8),
              _typeBtn('income', Icons.trending_up, AppColors.success, context.tr('planned_payments.income')),
              const SizedBox(width: 8),
              _typeBtn('transfer', Icons.swap_horiz, AppColors.transfer, context.tr('planned_payments.transfer')),
            ],
          ),
        ],
      );

  Widget _typeBtn(String type, IconData icon, Color color, String label) {
    final active = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          _categoryId = null;
          if (type != 'transfer') _toAccountId = null;
        }),
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
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : AppColors.textFor(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryField(BuildContext context, FinanceStore store) {
    final cats = store.categories.where((c) => c.type == _type).toList();
    final selected = cats.where((c) => c.id == _categoryId).firstOrNull;
    return _buildPicker(
      label: context.tr('planned_payments.category'),
      value: selected != null ? tCat(context, selected.name) : null,
      onTap: () async {
        final result = await GroupedPickerSheet.show<String>(
          context: context,
          title: context.tr('planned_payments.category'),
          items: cats.map((c) => c.id).toList(),
          labelBuilder: (id) => tCat(context, cats.firstWhere((c) => c.id == id).name),
          groupBuilder: (id) {
            final c = cats.firstWhere((c) => c.id == id);
            if (c.parentId == null || c.parentId!.isEmpty) return '';
            final parent = store.categories.where((p) => p.id == c.parentId);
            return parent.isNotEmpty ? tCat(context, parent.first.name) : '';
          },
          iconBuilder: (id) => categoryIconFor(cats.firstWhere((c) => c.id == id), allCategories: store.categories),
          colorBuilder: (id) => _type == 'income' ? AppColors.income : AppColors.expense,
          selectedId: _categoryId,
        );
        if (result != null) setState(() => _categoryId = result);
      },
    );
  }

  Widget _buildPicker({required String label, required String? value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label + ':'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: AppColors.cardFor(context), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderFor(context))),
            child: Row(
              children: [
                Expanded(child: Text(value ?? '', style: TextStyle(fontSize: 16, color: value != null ? AppColors.textFor(context) : AppColors.textSecondaryFor(context)))),
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

  Widget _toAccountField(BuildContext context, FinanceStore store) {
    final accounts = store.accounts.where((a) => !a.isArchived && a.id != _accountId).toList();
    final selected = accounts.where((a) => a.id == _toAccountId).firstOrNull;
    return _buildPicker(
      label: context.tr('operations.to_account'),
      value: selected?.name,
      onTap: () async {
        final result = await GroupedPickerSheet.show<String>(
          context: context,
          title: context.tr('operations.to_account'),
          items: accounts.map((a) => a.id).toList(),
          labelBuilder: (id) => accounts.firstWhere((a) => a.id == id).name,
          groupBuilder: (id) => accounts.firstWhere((a) => a.id == id).currency,
          subtitleBuilder: (id) {
            final a = accounts.firstWhere((a) => a.id == id);
            return '${a.balance.toStringAsFixed(2)} ${a.currency}';
          },
          iconBuilder: (id) => _accountIcon(accounts.firstWhere((a) => a.id == id).icon),
          colorBuilder: (id) => _hexToColor(accounts.firstWhere((a) => a.id == id).color),
          selectedId: _toAccountId,
        );
        if (result != null) setState(() => _toAccountId = result);
      },
    );
  }

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

    final hh = _hourCtrl.text.trim().padLeft(2, '0');
    final mm = _minuteCtrl.text.trim().padLeft(2, '0');
    final timeStr = '$hh:$mm:00';

    final event = FinancialEvent(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: comment.isNotEmpty ? comment : (widget.existing?.title ?? ''),
      date: dateStr,
      amount: amount,
      type: _type,
      comment: comment.isNotEmpty ? comment : widget.existing?.comment,
      tags: null,
      repeatMode: period,
      accountId: _accountId,
      toAccountId: _type == 'transfer' ? _toAccountId : null,
      categoryId: _categoryId,
      dayOfMonth: dayOfMonth,
      isRecurring: period > 0,
      weekDays: weekDays,
      dateStart: dateStart,
      dateEnd: dateEnd,
      repeatCount: _limitMode == 'count' ? int.tryParse(_repeatCountCtrl().text.trim()) : null,
      time: timeStr,
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
