import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
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
            ? store.operations.where((o) => o.id == operationId).firstOrNull
            : null;
        if (op == null) return Scaffold(body: Center(child: Text(context.tr('operations.not_found'))));

        final cat = store.getCategory(op.categoryId);
        final acc = store.getAccount(op.accountId);
        final toAcc = store.getAccount(op.toAccountId);

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('operations.title_detail')),
            actions: [
              if (op.type == 'expense')
                IconButton(
                  icon: const Icon(Icons.replay),
                  tooltip: context.tr('operations.refund'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(context.tr('operations.refund_confirm')),
                        content: Text('${formatMoney(op.amount)} — ${cat?.name ?? ''}'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('operations.cancel'))),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('operations.refund'))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await store.refundOperation(op);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.pushNamed(context, '/add-operation',
                    arguments: {'type': op.type, 'operationId': op.id}),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(context.tr('operations.delete_confirm')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('operations.cancel'))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('operations.delete'))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    store.deleteOperation(op.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(formatMoney(op.amount), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700,
                  color: op.type == 'income' ? AppColors.success : AppColors.expense)),
                const SizedBox(height: 8),
                Text(cat?.name ?? '', style: TextStyle(fontSize: 18, color: AppColors.textFor(context))),
                const SizedBox(height: 16),
                if (op.comment != null) Text(op.comment!, style: TextStyle(color: AppColors.textSecondaryFor(context))),
                const SizedBox(height: 8),
                if (acc != null) Text(context.tr('operations.account_from', namedArgs: {'name': acc.name}), style: TextStyle(color: AppColors.textSecondaryFor(context))),
                if (toAcc != null) Text(context.tr('operations.account_to', namedArgs: {'name': toAcc.name}), style: TextStyle(color: AppColors.textSecondaryFor(context))),
                const SizedBox(height: 8),
                Text(formatDateLong(op.date), style: TextStyle(color: AppColors.textSecondaryFor(context))),
              ],
            ),
          ),
        );
      },
    );
  }
}
