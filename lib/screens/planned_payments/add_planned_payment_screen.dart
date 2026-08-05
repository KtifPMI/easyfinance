import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';
import '../../components/common/app_button.dart';
import '../../components/common/app_input.dart';
import '../../components/common/grouped_picker_sheet.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/financial_event.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';
import '../../utils/category_icons.dart';
import '../../utils/format.dart';
import '../../utils/translate_category.dart';

class AddPlannedPaymentScreen extends StatefulWidget {
  final FinancialEvent? existing;
  final String? presetDate;
  const AddPlannedPaymentScreen({super.key, this.existing, this.presetDate});

  @override
  State<AddPlannedPaymentScreen> createState() => _AddPlannedPaymentScreenState();
}

class _AddPlannedPaymentScreenState extends State<AddPlannedPaymentScreen> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String _type = 'expense';
  int _repeatMode = 0;
  String? _accountId;
  String? _categoryId;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl.text = e?.title ?? '';
    _amountCtrl.text = e != null && e.amount > 0 ? e.amount.toString() : '';
    _commentCtrl.text = e?.comment ?? '';
    _tagsCtrl.text = e?.tags ?? '';
    _type = e?.type ?? 'expense';
    _repeatMode = e?.repeatMode ?? 0;
    _accountId = e?.accountId;
    _categoryId = e?.categoryId;
    if (e?.date != null && e!.date.isNotEmpty) {
      _date = DateTime.tryParse(e.date);
    }
    if (_date == null && widget.presetDate != null) {
      _date = DateTime.tryParse(widget.presetDate!);
    }
    _date ??= DateTime.now();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _commentCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FinanceStore>();
    final isEdit = widget.existing != null;

    return ScreenScaffold(
      title: context.tr(isEdit ? 'planned_payments.edit' : 'planned_payments.add'),
      showLogo: false,
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _typeToggle(context),
          const SizedBox(height: 16),
          AppInput(controller: _nameCtrl, label: context.tr('planned_payments.name')),
          const SizedBox(height: 12),
          AppInput(controller: _amountCtrl, label: context.tr('planned_payments.amount'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _datePicker(context),
          const SizedBox(height: 12),
          _repeatDropdown(context),
          const SizedBox(height: 12),
          _accountDropdown(context, store),
          const SizedBox(height: 12),
          _categoryPicker(context, store),
          const SizedBox(height: 12),
          AppInput(controller: _tagsCtrl, label: context.tr('planned_payments.tags'), hint: context.tr('planned_payments.tags_hint')),
          const SizedBox(height: 12),
          AppInput(controller: _commentCtrl, label: context.tr('planned_payments.comment'), maxLines: 2),
          const SizedBox(height: 24),
          AppButton(title: context.tr('planned_payments.save'), onPressed: _save),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _typeToggle(BuildContext context) {
    return Row(
      children: [
        _chip(context, 'income', context.tr('planned_payments.income'), AppColors.success),
        const SizedBox(width: 8),
        _chip(context, 'expense', context.tr('planned_payments.expense'), AppColors.expense),
      ],
    );
  }

  Widget _chip(BuildContext context, String type, String label, Color color) {
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
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? color : AppColors.textSecondaryFor(context))),
      ),
    );
  }

  Widget _datePicker(BuildContext context) {
    return InkWell(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardFor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderFor(context)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('planned_payments.date'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                  const SizedBox(height: 2),
                  Text(formatDateLong(_date?.toIso8601String().substring(0, 10) ?? ''), style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
                ],
              ),
            ),
            Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondaryFor(context)),
          ],
        ),
      ),
    );
  }

  Widget _repeatDropdown(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: _repeatMode,
      decoration: InputDecoration(
        labelText: context.tr('planned_payments.repeat_mode'),
        filled: true, fillColor: AppColors.cardFor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: [
        DropdownMenuItem(value: 0, child: Text(context.tr('planned_payments.repeat_none'))),
        DropdownMenuItem(value: 1, child: Text(context.tr('planned_payments.repeat_daily'))),
        DropdownMenuItem(value: 7, child: Text(context.tr('planned_payments.repeat_weekly'))),
        DropdownMenuItem(value: 30, child: Text(context.tr('planned_payments.repeat_monthly'))),
        DropdownMenuItem(value: 90, child: Text(context.tr('planned_payments.repeat_quarterly'))),
        DropdownMenuItem(value: 365, child: Text(context.tr('planned_payments.repeat_yearly'))),
      ],
      onChanged: (v) => setState(() => _repeatMode = v!),
    );
  }

  Widget _accountDropdown(BuildContext context, FinanceStore store) {
    final accounts = store.accounts.where((a) => !a.isArchived).toList();
    return DropdownButtonFormField<String>(
      initialValue: _accountId,
      decoration: InputDecoration(
        labelText: context.tr('planned_payments.account'),
        filled: true, fillColor: AppColors.cardFor(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) => setState(() => _accountId = v),
    );
  }

  Widget _categoryPicker(BuildContext context, FinanceStore store) {
    final cat = _categoryId != null ? store.categories.where((c) => c.id == _categoryId).firstOrNull : null;
    return InkWell(
      onTap: () async {
        final cats = store.categories.where((c) => c.type == _type).toList();
        if (cats.isEmpty) return;
        final selected = await GroupedPickerSheet.show<String>(
          context: context,
          title: context.tr('planned_payments.category'),
          items: cats.map((c) => c.id).toList(),
          labelBuilder: (id) => tCat(context, cats.firstWhere((c) => c.id == id).name),
          groupBuilder: (id) {
            final c = cats.firstWhere((c) => c.id == id);
            if (c.parentId == null || c.parentId!.isEmpty) return '';
            final parent = store.categories.where((p) => p.id == c.parentId);
            return parent.isNotEmpty ? parent.first.name : '';
          },
          iconBuilder: (id) => categoryIconFor(cats.firstWhere((c) => c.id == id), allCategories: store.categories),
          colorBuilder: (id) => _hexToColor(cats.firstWhere((c) => c.id == id).color),
          selectedId: _categoryId,
        );
        if (selected != null) setState(() => _categoryId = selected);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardFor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderFor(context)),
        ),
        child: Row(
          children: [
            if (cat != null) ...[
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: _hexToColor(cat.color).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Icon(categoryIconFor(cat, allCategories: store.categories), size: 16, color: _hexToColor(cat.color)),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                cat != null ? tCat(context, cat.name) : context.tr('planned_payments.category_hint'),
                style: TextStyle(fontSize: 15, color: cat != null ? AppColors.textFor(context) : AppColors.textSecondaryFor(context)),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondaryFor(context)),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final amount = (double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0).abs();
    if (amount <= 0) return;
    final store = context.read<PlannedPaymentStore>();

    final event = FinancialEvent(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: name,
      date: _date?.toIso8601String().substring(0, 10) ?? DateTime.now().toIso8601String().substring(0, 10),
      amount: amount,
      type: _type,
      comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      tags: _tagsCtrl.text.trim().isEmpty ? null : _tagsCtrl.text.trim(),
      repeatMode: _repeatMode,
      accountId: _accountId,
      categoryId: _categoryId,
      dayOfMonth: _repeatMode == 30 ? (_date?.day) : null,
      isRecurring: _repeatMode > 0,
      enabled: widget.existing?.enabled ?? true,
    );

    if (widget.existing != null) {
      store.update(widget.existing!.id, event);
    } else {
      store.add(event);
    }
    Navigator.pop(context);
  }
}
