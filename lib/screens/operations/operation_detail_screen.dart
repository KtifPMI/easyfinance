import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import 'package:provider/provider.dart';
import '../../store/finance_store.dart';

class OperationDetailScreen extends StatelessWidget {
  const OperationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final op = store.operations.isNotEmpty ? store.operations.first : null;
        if (op == null) return const Scaffold(body: Center(child: Text('Нет операций')));

        final cat = store.getCategory(op.categoryId);
        return Scaffold(
          appBar: AppBar(title: const Text('Операция')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(formatMoney(op.amount), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700,
                  color: op.type == 'income' ? AppColors.success : AppColors.expense)),
                const SizedBox(height: 8),
                Text(cat?.name ?? '', style: TextStyle(fontSize: 18, color: AppColors.text)),
                const SizedBox(height: 16),
                if (op.comment != null) Text(op.comment!, style: TextStyle(color: AppColors.textSecondary)),
                Text(formatDateLong(op.date), style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        );
      },
    );
  }
}
