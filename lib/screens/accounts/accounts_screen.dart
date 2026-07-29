import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/currency_utils.dart';
import 'add_account_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final accounts = store.accounts.toList()..sort((a, b) {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          return 0;
        });

        return ScreenScaffold(
          title: context.tr('accounts.title'),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAccountScreen())),
            child: const Icon(Icons.add),
          ),
          child: accounts.isEmpty
              ? Center(child: Text(context.tr('accounts.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context))))
              : Column(
                  children: [
                    AppCard(
                      child: Column(
                        children: [
                          Text(context.tr('accounts.my_capital'), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                          const SizedBox(height: 4),
                          Text(store.fmt(store.totalBalance), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textFor(context))),
                          if (accounts.where((a) => !a.isArchived).length > 1) ...[
                            const SizedBox(height: 4),
                            Text(_buildCurrencyBreakdown(store), style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...accounts.map((a) {
                    final iconMap = {'cash': Icons.money, 'credit_card': Icons.credit_card, 'savings': Icons.savings, 'account_balance': Icons.account_balance, 'wallet': Icons.account_balance_wallet, 'payments': Icons.payments};
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
                                    Row(
                                      children: [
                                        Text(a.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                                        if (a.isArchived) ...[
                                          const SizedBox(width: 6),
                                          Text(context.tr('accounts.archived'), style: TextStyle(fontSize: 11, color: AppColors.textSecondaryFor(context))),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(store.fmt(a.balance, fromCurrency: a.currency), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: a.balance >= 0 ? AppColors.textFor(context) : AppColors.expense)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () async {
                                  final sp = await SharedPreferences.getInstance();
                                  await sp.setBool('fav_${a.id}', !a.isFavorite);
                                  store.updateAccountFavorite(a.id, !a.isFavorite);
                                },
                                child: Icon(
                                  a.isFavorite ? Icons.star : Icons.star_border,
                                  color: a.isFavorite ? Colors.amber : AppColors.textSecondaryFor(context),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right, color: AppColors.textSecondaryFor(context)),
                            ],
                          ),
                        ),
                      ),
                    );
                    }),
                  ],
                ),
        );
      },
    );
  }

  String _buildCurrencyBreakdown(FinanceStore store) {
    final byCurrency = <String, double>{};
    for (final a in store.accounts.where((a) => !a.isArchived)) {
      byCurrency.update(a.currency, (v) => v + a.balance, ifAbsent: () => a.balance);
    }
    final entries = byCurrency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => '${currencySymbol(e.key)}${store.fmt(e.value, fromCurrency: e.key)}').join('  ·  ');
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
