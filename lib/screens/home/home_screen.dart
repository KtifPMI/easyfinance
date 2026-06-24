import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/home/fin_health_card.dart';
import '../../components/home/quick_actions.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/calc.dart';
import '../../utils/format.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final indicators = calcFinHealth(store.accounts, store.operations, store.budgets);

        return ScreenScaffold(
          title: 'EasyFinance',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Общий баланс', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(formatMoney(store.totalBalance), style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _chip('+${formatMoney(store.monthIncome)}', AppColors.success),
                        const SizedBox(width: 12),
                        _chip('-${formatMoney(store.monthExpense)}', AppColors.expense),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              QuickActions(
                onAddIncome: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'income'}),
                onAddExpense: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'expense'}),
                onAddTransfer: () => Navigator.pushNamed(context, '/add-operation', arguments: {'type': 'transfer'}),
              ),
              const SizedBox(height: 16),
              FinHealthCard(indicators: indicators),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
