import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../components/common/app_card.dart';
import '../../components/common/screen_scaffold.dart';
import '../../models/account.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/currency_utils.dart';
import '../../services/currency_rate_service.dart';
import '../../utils/color_utils.dart';
import '../../utils/format.dart';
import 'add_account_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  String _search = '';
  final Set<String> _revealed = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        final all = store.accounts.where((a) => !a.isArchived).toList();
        final hidden = store.accounts.where((a) => a.isArchived).toList();
        all.sort((a, b) {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          final ga = groupOrder[groupForType(a.type)] ?? 99;
          final gb = groupOrder[groupForType(b.type)] ?? 99;
          return ga != gb ? ga.compareTo(gb) : a.name.compareTo(b.name);
        });

        final accounts = _search.isEmpty
            ? all
            : all.where((a) => a.name.toLowerCase().contains(_search.toLowerCase())).toList();

        final grouped = <String, List<Account>>{};
        for (final a in accounts) {
          (grouped[groupForType(a.type)] ??= []).add(a);
        }

        return ScreenScaffold(
          title: context.tr('accounts.title'),
          showLogo: false,
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAccountScreen())),
            child: const Icon(Icons.add),
          ),
          child: accounts.isEmpty && all.isNotEmpty
              ? Center(child: Text(context.tr('common.no_results'), style: TextStyle(color: AppColors.textSecondaryFor(context))))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: context.tr('common.search'),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: AppColors.cardFor(context),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    if (accounts.isEmpty)
                      Center(child: Text(context.tr('accounts.empty'), style: TextStyle(color: AppColors.textSecondaryFor(context))))
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              AppCard(
                                child: Column(
                                  children: [
                                    Text(context.tr('accounts.my_capital'), style: TextStyle(fontSize: 13, color: AppColors.textSecondaryFor(context))),
                                    const SizedBox(height: 4),
                                    Text(store.fmt(store.totalBalance), style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, color: AppColors.textFor(context))),
                                    if (all.where((a) => !a.isArchived).length > 1) ...[
                                      const SizedBox(height: 8),
                                      _buildCurrencyRow(context, store),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                               ..._buildGrouped(context, store, grouped),
                               if (hidden.isNotEmpty) ...[
                                 const SizedBox(height: 16),
                                 Text(context.tr('accounts.hidden'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context))),
                                 const SizedBox(height: 8),
                                 ...hidden.map((a) => _accountTile(context, store, a)),
                               ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _buildGrouped(BuildContext context, FinanceStore store, Map<String, List<Account>> grouped) {
    final order = ['money', 'owed_by_me', 'owed_to_me', 'investments', 'property', 'loyalty'];
    final result = <Widget>[];
    for (final group in order) {
      final list = grouped[group];
      if (list == null || list.isEmpty) continue;
      result.add(_groupHeader(context, store, group, list));
      result.add(const SizedBox(height: 8));
      for (final a in list) {
        result.add(_accountTile(context, store, a));
      }
      result.add(const SizedBox(height: 4));
    }
    return result;
  }

  Widget _groupHeader(BuildContext context, FinanceStore store, String group, List<Account> list) {
    final total = list.where((a) => a.includeInTotal).fold<double>(0, (s, a) => s + CurrencyRateService.convert(store.accountActualBalance(a), a.currency, 'RUB', store.rates));
    final labels = {
      'money': 'accounts.group.money',
      'owed_by_me': 'accounts.group.owed_by_me',
      'owed_to_me': 'accounts.group.owed_to_me',
      'investments': 'accounts.group.investments',
      'property': 'accounts.group.property',
      'loyalty': 'accounts.group.loyalty',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(
            context.tr(labels[group] ?? ''),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondaryFor(context)),
          ),
          if (list.where((a) => a.includeInTotal).length > 1 && total != 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: total >= 0 ? AppColors.success.withValues(alpha: 0.12) : AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                store.fmt(total),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: total >= 0 ? AppColors.success : AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _accountTile(BuildContext context, FinanceStore store, Account a) {
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
                decoration: BoxDecoration(color: parseColor(a.color).withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(iconMap[a.icon] ?? Icons.account_balance, color: parseColor(a.color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textFor(context))),
                    Text(context.tr(accountTypeLabels[int.tryParse(_typeToId(a.type)) ?? 1] ?? 'accounts.type.cash'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondaryFor(context))),
                    if (a.isArchived)
                      Text(context.tr('accounts.hidden'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.warning)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: a.isArchived ? () => setState(() {
                  if (_revealed.contains(a.id)) {
                    _revealed.remove(a.id);
                  } else {
                    _revealed.add(a.id);
                  }
                }) : null,
                child: Text(
                  a.isArchived && !_revealed.contains(a.id) ? '***' : formatMoney(store.accountActualBalance(a), currency: a.currency),
                  maxLines: 1, softWrap: false,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: store.accountActualBalance(a) >= 0 ? AppColors.textFor(context) : AppColors.expense),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => store.updateAccountFavorite(a.id, !a.isFavorite),
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
  }

  String _typeToId(String type) {
    switch (type) {
      case 'cash': return '1';
      case 'card': return '2';
      case 'deposit': return '5';
      case 'loan_given': return '6';
      case 'loan_received': return '7';
      case 'credit_card': return '8';
      case 'credit': return '9';
      case 'oms': return '10';
      case 'stocks': return '11';
      case 'pif': return '12';
      case 'ofbu': return '13';
      case 'pension': return '14';
      case 'electronic': return '15';
      case 'bank_account': return '16';
      case 'real_estate': return '17';
      case 'car': return '18';
      case 'other_securities': return '19';
      case 'fund': return '20';
      case 'insurance_savings': return '21';
      case 'savings_plan': return '22';
      case 'npf': return '23';
      case 'water_transport': return '24';
      case 'art': return '25';
      case 'business': return '26';
      case 'other_property': return '27';
      case 'air_transport': return '28';
      case 'motorcycle': return '29';
      case 'bonds': return '30';
      case 'pamm': return '31';
      case 'broker': return '32';
      case 'bonus_card': return '33';
      default: return '1';
    }
  }

  Widget _buildCurrencyRow(BuildContext context, FinanceStore store) {
    final byCurrency = <String, double>{};
    for (final a in store.accounts.where((a) => !a.isArchived)) {
      byCurrency.update(a.currency, (v) => v + store.accountActualBalance(a), ifAbsent: () => store.accountActualBalance(a));
    }
    final entries = byCurrency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardFor(context).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderFor(context)),
          ),
          child: Text(
            '${currencySymbol(e.key)} ${formatMoney(e.value, currency: e.key)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textFor(context)),
          ),
        );
      }).toList(),
    );
  }
}
