import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/progress_bar.dart';
import '../../components/common/screen_hint.dart';
import '../../components/common/screen_scaffold.dart';
import '../../components/home/fin_health_card.dart';
import '../../components/home/quick_actions.dart';
import '../../store/finance_store.dart';
import '../../models/financial_event.dart';
import '../../theme/theme.dart';
import '../../utils/calc.dart';
import '../../utils/format.dart';
import '../../store/planned_payment_store.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<FinanceStore, PlannedPaymentStore>(
      builder: (context, store, plannedPayments, _) {
        final indicators = calcFinHealth(store.accounts, store.operations, store.budgets);

        return ScreenScaffold(
          title: 'EasyFinance',
          isLoading: store.isLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHint(hintId: 'home', text: 'Здесь вы видите общий баланс, бюджет на месяц и ближайшие платежи. Добавляйте доходы и расходы через кнопки быстрых действий.'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('home.total_balance'), style: TextStyle(color: Colors.white70, fontSize: 13)),
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
              const SizedBox(height: 16),
              if (store.recommendations.isNotEmpty) ...[
                Text(context.tr('home.recommendations'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 8),
                ...store.recommendations.take(3).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AppCard(
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(r.title, style: TextStyle(fontSize: 13, color: AppColors.text))),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 16),
              ],
              if (store.budgets.isNotEmpty) ...[
                Text(context.tr('home.month_budget'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 8),
                ...store.budgets.where((b) => !b.isDeleted).take(3).map((b) {
                  final cat = store.getCategory(b.categoryId);
                  final percent = b.limit > 0 ? (b.spent / b.limit * 100) : 0.0;
                  final color = cat?.color != null ? _parseColor(cat!.color) : AppColors.primary;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(b.name ?? cat?.name ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                              Text('${formatMoney(b.spent)} / ${formatMoney(b.limit)}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ProgressBar(percent: percent, color: color),
                          Text('${percent.round()}%', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
              if (store.goals.isNotEmpty) ...[
                Text(context.tr('home.goals'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 8),
                ...store.goals.where((g) => !g.isCompleted).take(3).map((g) {
                  final percent = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount * 100) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(g.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                              ),
                              Text('${percent.round()}%', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ProgressBar(percent: percent, color: _parseColor(g.color)),
                          Text('${formatMoney(g.currentAmount)} / ${formatMoney(g.targetAmount)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
              if (plannedPayments.upcomingExpenses.isNotEmpty || plannedPayments.upcomingIncomes.isNotEmpty) ...[
                Text(context.tr('home.upcoming_payments'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 8),
                ...plannedPayments.upcomingEvents.take(5).map((e) => _upcomingTile(e)),
                _manageButton(context),
                const SizedBox(height: 16),
              ],
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

  Widget _upcomingTile(FinancialEvent e) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: AppCard(
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (e.type == 'income' ? AppColors.success : AppColors.expense).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(e.type == 'income' ? Icons.arrow_downward : Icons.arrow_upward, size: 20, color: e.type == 'income' ? AppColors.success : AppColors.expense),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                Text(formatDate(e.date), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(formatMoney(e.amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: e.type == 'income' ? AppColors.success : AppColors.expense)),
        ],
      ),
    ),
  );

  Widget _manageButton(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: TextButton(
      onPressed: () => Navigator.pushNamed(context, '/planned-payments'),
      child: Text(context.tr('home.manage_planned'), style: TextStyle(fontSize: 13, color: AppColors.primary)),
    ),
  );

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
