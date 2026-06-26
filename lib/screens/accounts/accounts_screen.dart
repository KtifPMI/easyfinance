import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';
import 'add_account_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return ScreenScaffold(
          title: 'Счета',
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAccountScreen())),
            ),
          ],
          child: store.accounts.isEmpty
              ? Center(child: Text('Нет счетов', style: TextStyle(color: AppColors.textSecondary)))
              : Column(
                  children: store.accounts.map((a) {
                    final iconMap = {'cash': Icons.money, 'credit_card': Icons.credit_card, 'savings': Icons.savings, 'account_balance': Icons.account_balance, 'wallet': Icons.wallet, 'payments': Icons.payments};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddAccountScreen(accountId: a.id))),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: _parseColor(a.color).withValues(alpha: 0.15), shape: BoxShape.circle),
                                child: Icon(iconMap[a.icon] ?? Icons.account_balance, color: _parseColor(a.color)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                                    if (a.isArchived) Text('Архивный', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              Text(formatMoney(a.balance), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: a.balance >= 0 ? AppColors.text : AppColors.expense)),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
