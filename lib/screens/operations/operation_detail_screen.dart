import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/operation.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import '../../utils/translate_category.dart';
import 'package:provider/provider.dart';
import '../../store/finance_store.dart';

class OperationDetailScreen extends StatelessWidget {
  const OperationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final operationId = args?['operationId'] as String?;

    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final op = operationId != null
            ? store.operations.where((o) => o.id == operationId && !o.isDeleted).firstOrNull
            : null;
        if (op == null) return Scaffold(body: Center(child: Text(context.tr('operations.not_found'))));

        final cat = store.getCategory(op.categoryId);
        final acc = store.getAccount(op.accountId);
        final toAcc = store.getAccount(op.toAccountId);

        return ScreenScaffold(
          title: context.tr('operations.title_detail'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _amountCard(context, op, cat),
              const SizedBox(height: 10),
              _detailCard(context, op, store, acc, toAcc),
              if (op.comment != null && op.comment!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _commentCard(context, op),
              ],
              if (op.tags != null && op.tags!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _tagsCard(context, op),
              ],
              const Spacer(),
              _bottomActions(context, store, op),
            ],
          ),
        );
      },
    );
  }

  Widget _amountCard(BuildContext context, Operation op, dynamic cat) {
    return AppCard(
      child: Column(
        children: [
          Text(
            formatMoneyOps(op.amount),
            style: TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.w700,
              color: op.type == 'income' ? AppColors.success : AppColors.expense,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tCat(context, cat?.name ?? ''),
            style: TextStyle(fontSize: 17, color: AppColors.textSecondaryFor(context)),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(BuildContext context, Operation op, FinanceStore store, dynamic acc, dynamic toAcc) {
    final dt = DateTime.tryParse(op.date);
    final dateStr = dt != null
        ? '${formatDateLong(op.date)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : formatDateLong(op.date);

    return AppCard(
      child: Column(
        children: [
          if (acc != null) _infoRow(context, context.tr('operations.account'), acc.name),
          if (toAcc != null) _infoRow(context, context.tr('operations.account_to'), toAcc.name),
          _infoRow(context, context.tr('operations.date'), dateStr),
          if (op.type == 'transfer' && toAcc != null && acc != null)
            _infoRow(context, context.tr('operations.rate'), _transferRate(op, store, acc, toAcc)),
        ],
      ),
    );
  }

  Widget _commentCard(BuildContext context, Operation op) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('operations.comment'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
            const SizedBox(height: 4),
            Text(op.comment!, style: TextStyle(fontSize: 15, color: AppColors.textFor(context))),
          ],
        ),
      ),
    );
  }

  Widget _tagsCard(BuildContext context, Operation op) {
    final tags = op.tags!.split(',').where((e) => e.trim().isNotEmpty).toList();
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('operations.tags'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags.map((t) => Chip(
                label: Text('#${t.trim()}', style: const TextStyle(fontSize: 13)),
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                labelStyle: TextStyle(color: AppColors.primary, fontSize: 13),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions(BuildContext context, FinanceStore store, Operation op) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.copy, size: 24),
            tooltip: context.tr('operations.copy'),
            onPressed: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': op.type, 'copyFrom': op.id}),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 24),
            tooltip: context.tr('operations.edit'),
            onPressed: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': op.type, 'operationId': op.id}),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 24),
            tooltip: context.tr('operations.delete'),
            onPressed: () => _confirmDelete(context, store, op),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSecondaryFor(context))),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textFor(context))),
          ),
        ],
      ),
    );
  }

  String _transferRate(Operation op, FinanceStore store, dynamic acc, dynamic toAcc) {
    if (op.transferAmount != null && op.transferAmount! > 0 && op.amount > 0) {
      return (op.transferAmount! / op.amount).toStringAsFixed(2);
    }
    return '1.00';
  }

  void _confirmDelete(BuildContext context, FinanceStore store, Operation op) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('operations.delete_confirm')),
        content: Text('${formatMoney(op.amount)} — ${op.comment ?? ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('operations.cancel'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await store.deleteOperation(op.id);
              if (!context.mounted) return;
              if (store.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store.error!), backgroundColor: AppColors.danger));
              } else {
                Navigator.pop(context);
              }
            },
            child: Text(context.tr('operations.delete'), style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}
