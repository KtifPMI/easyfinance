import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/financial_event.dart';
import '../../store/planned_payment_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

class PlannedPaymentsScreen extends StatelessWidget {
  const PlannedPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlannedPaymentStore>(
      builder: (context, store, _) {
        final incomes = store.events.where((e) => e.type == 'income' && e.enabled).toList();
        final expenses = store.events.where((e) => e.type == 'expense' && e.enabled).toList();
        final disabled = store.events.where((e) => !e.enabled).toList();

        return ScreenScaffold(
          title: context.tr('planned_payments.title'),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _add(context),
            child: const Icon(Icons.add),
          ),
          child: store.events.isEmpty
              ? Center(child: Text(context.tr('planned_payments.empty'), style: TextStyle(color: AppColors.textSecondary)))
              : ListView(
                  children: [
                    if (incomes.isNotEmpty) ...[
                      _sectionHeader(context, context.tr('planned_payments.income')),
                      ...incomes.map((e) => _paymentTile(context, e)),
                      const SizedBox(height: 8),
                    ],
                    if (expenses.isNotEmpty) ...[
                      _sectionHeader(context, context.tr('planned_payments.expense')),
                      ...expenses.map((e) => _paymentTile(context, e)),
                      const SizedBox(height: 8),
                    ],
                    if (disabled.isNotEmpty) ...[
                      _sectionHeader(context, context.tr('planned_payments.disabled')),
                      ...disabled.map((e) => _paymentTile(context, e)),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );
  }

  Widget _paymentTile(BuildContext context, FinancialEvent e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (e.type == 'income' ? AppColors.success : AppColors.expense).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(e.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward, size: 20,
                color: e.enabled ? (e.type == 'income' ? AppColors.success : AppColors.expense) : AppColors.textSecondary),
          ),
          title: Text(e.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: e.enabled ? AppColors.text : AppColors.textSecondary)),
          subtitle: Text(
            e.isRecurring ? '${context.tr('planned_payments.day')} ${e.dayOfMonth}' : formatDate(e.date),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatMoney(e.amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: e.enabled ? (e.type == 'income' ? AppColors.success : AppColors.expense) : AppColors.textSecondary)),
              const SizedBox(width: 4),
              Switch(
                value: e.enabled,
                onChanged: (_) => context.read<PlannedPaymentStore>().toggleEnabled(e.id),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          onTap: () => _edit(context, e),
          onLongPress: () => _delete(context, e),
        ),
      ),
    );
  }

  void _add(BuildContext context) {
    Navigator.pushNamed(context, '/add-planned-payment');
  }

  void _edit(BuildContext context, FinancialEvent e) {
    Navigator.pushNamed(context, '/add-planned-payment', arguments: e);
  }

  void _delete(BuildContext context, FinancialEvent e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('planned_payments.confirm_delete')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('planned_payments.cancel'))),
          TextButton(
            onPressed: () {
              context.read<PlannedPaymentStore>().remove(e.id);
              Navigator.pop(ctx);
            },
            child: Text(context.tr('planned_payments.delete'), style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}
