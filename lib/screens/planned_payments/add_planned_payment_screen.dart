import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/financial_event.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';

class AddPlannedPaymentScreen extends StatefulWidget {
  final FinancialEvent? existing;
  const AddPlannedPaymentScreen({super.key, this.existing});

  @override
  State<AddPlannedPaymentScreen> createState() => _AddPlannedPaymentScreenState();
}

class _AddPlannedPaymentScreenState extends State<AddPlannedPaymentScreen> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _dayController;
  late TextEditingController _commentController;
  late String _type;
  late bool _isRecurring;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(text: e != null && e.amount > 0 ? e.amount.toString() : '');
    _dayController = TextEditingController(text: e?.dayOfMonth?.toString() ?? '');
    _commentController = TextEditingController(text: e?.comment ?? '');
    _type = e?.type ?? 'expense';
    _isRecurring = e?.isRecurring ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dayController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return ScreenScaffold(
      title: context.tr(isEdit ? 'planned_payments.edit' : 'planned_payments.add'),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('planned_payments.type'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeChip('income', Icons.arrow_downward, AppColors.success),
                const SizedBox(width: 8),
                _typeChip('expense', Icons.arrow_upward, AppColors.expense),
              ],
            ),
            const SizedBox(height: 16),
            AppInput(
              controller: _nameController,
              label: context.tr('planned_payments.name'),
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: _amountController,
              label: context.tr('planned_payments.amount'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: _dayController,
                    label: context.tr('planned_payments.day'),
                    hint: context.tr('planned_payments.day_hint'),
                    keyboardType: TextInputType.number,
                    enabled: _isRecurring,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('planned_payments.recurring'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                    Switch(
                      value: _isRecurring,
                      onChanged: (v) => setState(() => _isRecurring = v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: _commentController,
              label: context.tr('planned_payments.comment'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            AppButton(
              title: context.tr('planned_payments.save'),
              onPressed: _save,
            ),
          ],
      ),
    );
  }

  Widget _typeChip(String type, IconData icon, Color color) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : AppColors.cardFor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : AppColors.borderFor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? color : AppColors.textSecondaryFor(context)),
            const SizedBox(width: 6),
            Text(
              context.tr('planned_payments.$type'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? color : AppColors.textSecondaryFor(context)),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    int? dayOfMonth;
    if (_isRecurring) {
      dayOfMonth = int.tryParse(_dayController.text.trim());
      if (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 31) return;
    }

    final now = DateTime.now();
    String date;
    if (_isRecurring && dayOfMonth != null) {
      var next = _dateForDay(now.year, now.month, dayOfMonth);
      if (next.isBefore(DateTime(now.year, now.month, now.day))) {
        next = _dateForDay(now.year, now.month + 1, dayOfMonth);
      }
      date = next.toIso8601String().substring(0, 10);
    } else {
      date = now.toIso8601String().substring(0, 10);
    }

    final store = context.read<PlannedPaymentStore>();

    final event = FinancialEvent(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: name,
      date: date,
      amount: amount,
      type: _type,
      comment: _commentController.text.trim(),
      isRecurring: _isRecurring,
      dayOfMonth: dayOfMonth,
      enabled: widget.existing?.enabled ?? true,
    );

    if (widget.existing != null) {
      store.update(widget.existing!.id, event);
    } else {
      store.add(event);
    }

    Navigator.pop(context);
  }

  DateTime _dateForDay(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }
}
