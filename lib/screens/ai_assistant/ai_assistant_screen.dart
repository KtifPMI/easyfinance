import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/operation.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

class _ChatMessage {
  final String role;
  final String text;
  final String? navLabel;
  final String? navRoute;
  _ChatMessage({required this.role, required this.text, this.navLabel, this.navRoute});
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _ctrl = TextEditingController();
  final _messages = <_ChatMessage>[];
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _messages.add(_ChatMessage(role: 'user', text: text)));
    final store = context.read<FinanceStore>();
    final reply = _analyze(text, store);
    setState(() => _messages.add(reply));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _quickCommand(String command) {
    _ctrl.text = command;
    _send();
  }

  void _navigate(String route) {
    const tabRoutes = {'/main', '/operations', '/plan', '/calendar', '/reports'};
    if (tabRoutes.contains(route)) {
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  _ChatMessage _analyze(String query, FinanceStore store) {
    final q = query.toLowerCase();
    final now = DateTime.now();
    final ms = DateTime(now.year, now.month, 1);
    final me = DateTime(now.year, now.month + 1, 0);

    bool inRange(Operation o) {
      final d = DateTime.tryParse(o.date);
      return d != null && !d.isBefore(ms) && !d.isAfter(me);
    }

    final mi = store.operations.where((o) => o.type == 'income' && inRange(o)).fold(0.0, (s, o) => s + o.amount);
    final mexp = store.operations.where((o) => o.type == 'expense' && inRange(o)).fold(0.0, (s, o) => s + o.amount);
    final sav = mi - mexp;
    final accountsTotal = store.totalBalance;

    final catExps = <String, double>{};
    for (final o in store.operations.where((o) => o.type == 'expense' && inRange(o))) {
      final c = store.categories.where((x) => x.id == o.categoryId).firstOrNull;
      if (c != null) catExps.update(c.name, (v) => v + o.amount, ifAbsent: () => o.amount);
    }
    final topCat = catExps.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final budgets = store.budgets;
    final goals = store.goals;
    final recs = store.recommendations;
    final accs = store.accounts.where((a) => !a.isArchived).toList();

    // ---- BALANCE ----
    if (_match(q, ['баланс', 'сколько денег', 'сколько всего', 'мой баланс', 'мои деньги', 'общий счёт', 'balance', 'how much money', 'total'])) {
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.balance_title')}\n\n${accs.map((a) => '• ${a.name}: ${store.fmt(a.balance, fromCurrency: a.currency)}').join('\n')}\n\n${context.tr('ai.total')}: ${store.fmt(accountsTotal)}', navLabel: context.tr('ai.nav_accounts'), navRoute: '/accounts');
    }

    // ---- INCOME ----
    if (_match(q, ['доход', 'доходы', 'заработал', 'заработок', 'приход', 'сколько получил', 'income', 'earned', 'earnings', 'revenue', 'поступления'])) {
      final incomes = store.operations.where((o) => o.type == 'income' && inRange(o)).toList()..sort((a, b) => b.date.compareTo(a.date));
      final top = incomes.take(5).map((o) {
        final cat = store.categories.where((c) => c.id == o.categoryId).firstOrNull;
        return '• ${formatDate(o.date)}: ${cat?.name ?? '—'} — ${store.fmt(o.amount, fromCurrency: store.accounts.where((a) => a.id == o.accountId).firstOrNull?.currency ?? 'RUB', date: o.date)}';
      }).join('\n');
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.month_income', namedArgs: {'income': store.fmt(mi), 'expense': store.fmt(mexp), 'balance': store.fmt(sav)})}\n\n${top.isNotEmpty ? top : context.tr('ai.no_income')}', navLabel: context.tr('ai.nav_operations'), navRoute: '/operations');
    }

    // ---- EXPENSES ----
    if (_match(q, ['расход', 'расходы', 'трат', 'потратил', 'ушло', 'списание', 'expense', 'spent', 'spending', 'cost', 'costs'])) {
      final top5 = topCat.take(5).map((e) => '• ${e.key}: ${store.fmt(e.value)} (${(e.value / mexp * 100).round()}%)').join('\n');
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.month_expense', namedArgs: {'amount': store.fmt(mexp)})}\n\n$top5', navLabel: context.tr('ai.nav_reports'), navRoute: '/reports');
    }

    // ---- CATEGORIES ----
    if (_match(q, ['категор', 'структура', 'на что', 'куда уходят', 'разбивка', 'category', 'categories', 'breakdown', 'break down', 'where'])) {
      final all = topCat.map((e) => '• ${e.key}: ${store.fmt(e.value)} (${(e.value / mexp * 100).round()}%)').join('\n');
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.expense_categories')}\n\n${all.isNotEmpty ? all : context.tr('ai.no_category_data')}', navLabel: context.tr('ai.nav_reports'), navRoute: '/reports');
    }

    // ---- SAVINGS ----
    if (_match(q, ['сбережен', 'накоплен', 'отложил', 'остаток', 'экономия', 'свободн', 'saving', 'savings', 'leftover', 'remain', 'surplus'])) {
      final rate = mi > 0 ? (sav / mi * 100).round() : 0;
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.savings_info', namedArgs: {'savings': store.fmt(sav), 'rate': '$rate', 'income': store.fmt(mi)})}\n\n${rate < 10 ? context.tr('ai.savings_low') : rate < 30 ? context.tr('ai.savings_ok') : context.tr('ai.savings_great')}', navLabel: context.tr('ai.nav_budget'), navRoute: '/plan');
    }

    // ---- BUDGETS ----
    if (_match(q, ['бюджет', 'лимит', 'план', 'превышен', 'перерасход', 'budget', 'limit', 'over', 'planned'])) {
      if (budgets.isEmpty) return _ChatMessage(role: 'assistant', text: context.tr('ai.no_budgets'), navLabel: context.tr('ai.nav_budget'), navRoute: '/plan');
      final parts = budgets.map((b) {
        final cat = store.categories.where((c) => c.id == b.categoryId).firstOrNull;
        final pct = b.limit > 0 ? (b.spent / b.limit * 100).round() : 0;
        final warn = pct > 100 ? ' 🔴' : pct > 80 ? ' 🟡' : ' 🟢';
        return '• ${b.name ?? cat?.name ?? '—'}: ${store.fmt(b.spent)} / ${store.fmt(b.limit)} ($pct%)$warn';
      }).join('\n');
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.budget_overview')}\n\n$parts', navLabel: context.tr('ai.nav_budget'), navRoute: '/plan');
    }

    // ---- GOALS ----
    if (_match(q, ['цел', 'мечт', 'коплю', 'копить', 'накопить', 'goal', 'target', 'dream', 'saving for'])) {
      if (goals.isEmpty) return _ChatMessage(role: 'assistant', text: context.tr('ai.no_goals'), navLabel: context.tr('ai.nav_goals'), navRoute: '/plan');
      final active = goals.where((g) => !g.isCompleted).toList();
      final done = goals.where((g) => g.isCompleted).toList();
      final parts = active.map((g) {
        final pct = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount * 100).round() : 0;
        final m = g.monthlyRecommendation;
        final rec = m != null && m > 0 && pct < 80 ? ' — ${context.tr('goals.recommendation', namedArgs: {'amount': store.fmt(m)})}' : '';
        return '• ${g.title}: ${store.fmt(g.currentAmount)} / ${store.fmt(g.targetAmount)} ($pct%)$rec';
      }).join('\n');
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.goals_overview', namedArgs: {'count': active.length.toString()})}\n\n$parts${done.isNotEmpty ? '\n\n${context.tr('ai.goals_completed', namedArgs: {'count': done.length.toString()})}' : ''}', navLabel: context.tr('ai.nav_goals'), navRoute: '/plan');
    }

    // ---- RECOMMENDATIONS / TIPS ----
    if (_match(q, ['совет', 'рекомендац', 'улучш', 'оптимиз', 'помощ', 'предлож', 'tip', 'recommend', 'advice', 'improve', 'suggest', 'help me'])) {
      if (recs.isEmpty) return _ChatMessage(role: 'assistant', text: context.tr('ai.no_recommendations'));
      final items = recs.map((r) => '• ${context.tr(r.titleKey, namedArgs: r.titleArgs)}\n  ${context.tr(r.descKey, namedArgs: r.descArgs)}').join('\n\n');
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.recommendations_title')}\n\n$items', navLabel: context.tr('ai.nav_recommendations'), navRoute: '/recommendations');
    }

    // ---- ACCOUNTS ----
    if (_match(q, ['счёт', 'счет', 'счета', 'карт', 'кошел', 'account', 'accounts', 'card', 'wallet'])) {
      final aText = accs.map((a) => '• ${a.name} (${a.type == 'credit' ? context.tr('accounts.type.credit') : context.tr('accounts.type.cash')}): ${store.fmt(a.balance, fromCurrency: a.currency)}${a.isFavorite ? ' ⭐' : ''}').join('\n');
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.accounts_count', namedArgs: {'count': accs.length.toString(), 'total': store.fmt(accountsTotal)})}\n\n$aText', navLabel: context.tr('ai.nav_accounts'), navRoute: '/accounts');
    }

    // ---- TOTAL / SUMMARY ----
    if (_match(q, ['итог', 'обзор', 'сводка', 'всё', 'все', 'резюме', 'summary', 'overview', 'total', 'everything', 'all'])) {
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.greeting')}\n\n${context.tr('ai.summary', namedArgs: {'balance': store.fmt(accountsTotal), 'income': store.fmt(mi), 'expense': store.fmt(mexp)})}\n\n${context.tr('ai.nav_help')}', navLabel: context.tr('ai.nav_home'), navRoute: '/main');
    }

    // ---- DEBTS ----
    if (_match(q, ['долг', 'кредит', 'задолжал', 'должен', 'рассрочк', 'ипотек', 'debt', 'credit', 'loan', 'mortgage', 'owe'])) {
      final debts = store.operations.where((o) => o.type == 'transfer' && inRange(o) && store.accounts.where((a) => a.id == o.toAccountId && a.type == 'credit').isNotEmpty).toList();
      final totalDebt = debts.fold(0.0, (s, o) => s + o.amount);
      return _ChatMessage(role: 'assistant', text: context.tr('ai.debt_info', namedArgs: {'amount': store.fmt(totalDebt), 'income': store.fmt(mi)}), navLabel: context.tr('ai.nav_accounts'), navRoute: '/accounts');
    }

    // ---- CALENDAR / PLANNED ----
    if (_match(q, ['календар', 'план', 'запланирован', 'напомин', 'платеж', 'предсто', 'calendar', 'plan', 'schedule', 'upcoming', 'reminder', 'next payment'])) {
      return _ChatMessage(role: 'assistant', text: context.tr('ai.calendar_hint'), navLabel: context.tr('ai.nav_calendar'), navRoute: '/calendar');
    }

    // ---- REPORT ----
    if (_match(q, ['отчёт', 'отчет', 'аналитик', 'статистик', 'график', 'диаграм', 'report', 'analysis', 'stats', 'chart', 'graph'])) {
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.report_hint')}\n\n${context.tr('ai.month_expense', namedArgs: {'amount': store.fmt(mexp)})}', navLabel: context.tr('ai.nav_reports'), navRoute: '/reports');
    }

    // ---- SETTINGS ----
    if (_match(q, ['настройк', 'язык', 'тема', 'тёмн', 'темн', 'пин', 'парол', 'валют', 'профил', 'settings', 'language', 'theme', 'dark', 'pin', 'password', 'profile', 'account info'])) {
      return _ChatMessage(role: 'assistant', text: context.tr('ai.settings_hint'), navLabel: context.tr('ai.nav_settings'), navRoute: '/settings');
    }

    // ---- SCAN ----
    if (_match(q, ['скан', 'чек', 'распозна', 'фото', 'камер', 'scan', 'receipt', 'photo', 'camera', 'ocr'])) {
      return _ChatMessage(role: 'assistant', text: context.tr('ai.scan_hint'), navLabel: context.tr('ai.nav_scan'), navRoute: '/scan-receipt');
    }

    // ---- GREETING ----
    if (_match(q, ['привет', 'здравствуй', 'добр', 'hello', 'hi', 'hey', 'good morning', 'good evening'])) {
      return _ChatMessage(role: 'assistant', text: '${context.tr('ai.greeting')}\n\n${context.tr('ai.summary', namedArgs: {'balance': store.fmt(accountsTotal), 'income': store.fmt(mi), 'expense': store.fmt(mexp)})}\n\n${context.tr('ai.nav_help')}');
    }

    return _ChatMessage(role: 'assistant', text: context.tr('ai.help'));
  }

  bool _match(String query, List<String> keywords) {
    return keywords.any((k) => query.contains(k.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceStore>(
      builder: (context, store, _) {
        return Scaffold(
          appBar: AppBar(title: Text(context.tr('ai_assistant.title'))),
          body: Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.smart_toy_outlined, size: 64, color: AppColors.textSecondaryFor(context)),
                            const SizedBox(height: 16),
                            Text(context.tr('ai_assistant.hint'), style: TextStyle(fontSize: 16, color: AppColors.textSecondaryFor(context))),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final isUser = msg.role == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                              child: Column(
                                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isUser ? AppColors.primary : AppColors.cardFor(context),
                                      borderRadius: BorderRadius.circular(12).copyWith(
                                        bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                                        bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                                      ),
                                    ),
                                    child: Text(msg.text, style: TextStyle(color: isUser ? Colors.white : AppColors.textFor(context), fontSize: 14)),
                                  ),
                                  if (!isUser && msg.navLabel != null && msg.navRoute != null) ...[
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () => _navigate(msg.navRoute!),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.open_in_new, size: 14, color: AppColors.primary),
                                            const SizedBox(width: 6),
                                            Text(msg.navLabel!, style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(color: AppColors.backgroundFor(context), boxShadow: [BoxShadow(color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          _actionChip(context.tr('ai.cmd_balance'), () => _quickCommand(context.tr('ai.cmd_balance'))),
                          _actionChip(context.tr('ai.cmd_income'), () => _quickCommand(context.tr('ai.cmd_income'))),
                          _actionChip(context.tr('ai.cmd_expenses'), () => _quickCommand(context.tr('ai.cmd_expenses'))),
                          _actionChip(context.tr('ai.cmd_categories'), () => _quickCommand(context.tr('ai.cmd_categories'))),
                          _actionChip(context.tr('ai.cmd_savings'), () => _quickCommand(context.tr('ai.cmd_savings'))),
                          _actionChip(context.tr('ai.cmd_budgets'), () => _quickCommand(context.tr('ai.cmd_budgets'))),
                          _actionChip(context.tr('ai.cmd_goals'), () => _quickCommand(context.tr('ai.cmd_goals'))),
                          _actionChip(context.tr('ai.cmd_debts'), () => _quickCommand(context.tr('ai.cmd_debts'))),
                          _actionChip(context.tr('ai.cmd_tips'), () => _quickCommand(context.tr('ai.cmd_tips'))),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl, onSubmitted: (_) => _send(),
                          decoration: InputDecoration(hintText: context.tr('ai_assistant.placeholder'), filled: true, fillColor: AppColors.cardFor(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: Icon(Icons.send, color: AppColors.primary), onPressed: _send),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.primaryLightFor(context), borderRadius: BorderRadius.circular(16)),
          child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
