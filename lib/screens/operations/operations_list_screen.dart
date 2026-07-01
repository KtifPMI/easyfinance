import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_chip.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/operations/operation_list_item.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

class OperationsListScreen extends StatefulWidget {
  const OperationsListScreen({super.key});

  @override
  State<OperationsListScreen> createState() => _OperationsListScreenState();
}

class _OperationsListScreenState extends State<OperationsListScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        var ops = store.operations.toList();
        if (_filter == 'income') ops = ops.where((o) => o.type == 'income').toList();
        if (_filter == 'expense') ops = ops.where((o) => o.type == 'expense').toList();

        final grouped = groupByDay(ops);

        return ScreenScaffold(
          title: context.tr('operations.title'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.pushNamed(context, '/add-operation'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHint(hintId: 'operations', text: 'Список всех операций — доходов, расходов и переводов. Используйте фильтр сверху, чтобы посмотреть только расходы или доходы.'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    AppChip(label: context.tr('operations.all'), active: _filter == 'all', onPressed: () => setState(() => _filter = 'all')),
                    AppChip(label: context.tr('operations.income'), active: _filter == 'income', onPressed: () => setState(() => _filter = 'income')),
                    AppChip(label: context.tr('operations.expense'), active: _filter == 'expense', onPressed: () => setState(() => _filter = 'expense')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (grouped.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(context.tr('operations.empty'), style: TextStyle(color: AppColors.textSecondary))))
              else
                ...grouped.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(formatDayLabel(entry.key, context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: entry.value.map((op) {
                          final cat = store.getCategory(op.categoryId);
                          final acc = store.getAccount(op.accountId);
                          final toAcc = store.getAccount(op.toAccountId);
                          final iconData = op.type == 'transfer' ? Icons.swap_horiz : (cat != null ? _catIcon(cat.icon) : Icons.help_outline);
                          final color = op.type == 'transfer' ? AppColors.transfer : (cat?.color != null ? _parseColor(cat!.color) : AppColors.textSecondary);
                          final title = op.type == 'transfer'
                              ? '${acc?.name ?? ''} → ${toAcc?.name ?? ''}'
                              : cat?.name ?? context.tr('operations.no_category');

                          return OperationListItem(
                            title: title,
                            subtitle: op.comment ?? acc?.name ?? '',
                            amount: op.amount,
                            type: op.type,
                            icon: iconData,
                            iconColor: color,
                            onTap: () => Navigator.pushNamed(context, '/operation-detail', arguments: {'operationId': op.id}),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                )),
            ],
          ),
        );
      },
    );
  }

  IconData _catIcon(String icon) {
    const map = {
      'shopping_cart': Icons.shopping_cart, 'directions_car': Icons.directions_car, 'restaurant': Icons.restaurant,
      'home': Icons.home, 'movie': Icons.movie, 'favorite': Icons.favorite, 'wifi': Icons.wifi,
      'checkroom': Icons.checkroom, 'payments': Icons.payments, 'laptop': Icons.laptop,
      'card_giftcard': Icons.card_giftcard, 'trending_up': Icons.trending_up,
      'food': Icons.restaurant, 'transport': Icons.directions_car, 'dining': Icons.local_cafe,
      'housing': Icons.home, 'shopping': Icons.shopping_bag, 'health': Icons.favorite,
      'entertainment': Icons.movie, 'education': Icons.school, 'travel': Icons.flight,
      'salary': Icons.payments, 'freelance': Icons.laptop, 'business': Icons.business,
      'gift': Icons.card_giftcard, 'car': Icons.directions_car, 'sports': Icons.fitness_center,
      'utilities': Icons.build, 'internet': Icons.wifi, 'clothing': Icons.checkroom,
      'children': Icons.child_care, 'pets': Icons.pets, 'taxes': Icons.receipt_long,
      'insurance': Icons.shield, 'invest': Icons.trending_up, 'rent': Icons.key,
      'other_income': Icons.attach_money, 'other_expense': Icons.money_off,
    };
    return map[icon] ?? Icons.help_outline;
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
