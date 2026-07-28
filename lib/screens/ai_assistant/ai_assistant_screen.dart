import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/operation.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _ctrl = TextEditingController();
  final _messages = <Map<String, String>>[];
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
    setState(() => _messages.add({'role': 'user', 'text': text}));
    final store = context.read<FinanceStore>();
    final reply = _analyze(text, store);
    setState(() => _messages.add({'role': 'assistant', 'text': reply}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _quickCommand(String command) {
    _ctrl.text = command;
    _send();
  }

  String _analyze(String query, FinanceStore store) {
    final q = query.toLowerCase();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    bool inRange(Operation o, [DateTime? start, DateTime? end]) {
      final d = DateTime.tryParse(o.date);
      if (d == null) return false;
      return !d.isBefore(start ?? monthStart) && !d.isAfter(end ?? monthEnd);
    }

    final monthIncome = store.operations.where((o) => o.type == 'income' && inRange(o)).fold(0.0, (s, o) => s + o.amount);
    final monthExpense = store.operations.where((o) => o.type == 'expense' && inRange(o)).fold(0.0, (s, o) => s + o.amount);

    if (q.contains('баланс') || (q.contains('сколько') && q.contains('денег')) || q.contains('balance') || q.contains('money')) {
      return '${context.tr('ai.balance_title')}\n\n${store.accounts.map((a) => '• ${a.name}: ${store.fmt(a.balance, fromCurrency: a.currency)}').join('\n')}';
    }

    if ((q.contains('трат') || q.contains('расход') || q.contains('spent') || q.contains('expense')) && q.contains('категори')) {
      final catName = store.categories.where((c) => q.contains(c.name.toLowerCase())).firstOrNull;
      if (catName != null) {
        final total = store.operations.where((o) => o.categoryId == catName.id && o.type == 'expense' && inRange(o)).fold(0.0, (s, o) => s + o.amount);
        return context.tr('ai.category_total', namedArgs: {'category': catName.name, 'amount': store.fmt(total)});
      }
      final totals = <String, double>{};
      for (final o in store.operations.where((o) => o.type == 'expense' && inRange(o))) {
        final cat = store.categories.where((c) => c.id == o.categoryId).firstOrNull;
        if (cat != null) totals.update(cat.name, (v) => v + o.amount, ifAbsent: () => o.amount);
      }
      final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return '${context.tr('ai.expense_categories')}\n${sorted.map((e) => '• ${e.key}: ${store.fmt(e.value)}').join('\n')}';
    }

    if (q.contains('трат') || q.contains('расход') || q.contains('expense') || q.contains('spent')) {
      return context.tr('ai.month_expense', namedArgs: {'amount': store.fmt(monthExpense)});
    }

    if (q.contains('доход') || q.contains('заработ') || q.contains('income') || q.contains('earn')) {
      return context.tr('ai.month_income', namedArgs: {'income': store.fmt(monthIncome), 'expense': store.fmt(monthExpense), 'balance': store.fmt(monthIncome - monthExpense)});
    }

    if (q.contains('счёт') || q.contains('счет') || q.contains('account')) {
      final total = store.accounts.fold(0.0, (s, a) => s + a.balance);
      return '${context.tr('ai.accounts_count', namedArgs: {'count': store.accounts.length.toString(), 'total': store.fmt(total)})}\n\n${store.accounts.map((a) => '• ${a.name}: ${store.fmt(a.balance, fromCurrency: a.currency)}').join('\n')}';
    }

    if (q.contains('цел') || q.contains('goal')) {
      if (store.goals.isEmpty) return context.tr('ai.no_goals');
      return store.goals.map((g) {
        final pct = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount * 100).round() : 0;
        return '• ${g.title}: ${store.fmt(g.currentAmount)} / ${store.fmt(g.targetAmount)} ($pct%)${g.isCompleted ? ' ✅' : ''}';
      }).join('\n');
    }

    if (q.contains('бюджет') || q.contains('budget')) {
      final budgets = store.budgets;
      if (budgets.isEmpty) return context.tr('ai.no_budgets');
      return budgets.map((b) {
        final cat = store.categories.where((c) => c.id == b.categoryId).firstOrNull;
        final name = b.name ?? cat?.name ?? '';
        final pct = b.limit > 0 ? (b.spent / b.limit * 100).round() : 0;
        return '• $name: ${store.fmt(b.spent)} / ${store.fmt(b.limit)} ($pct%)';
      }).join('\n');
    }

    if (q.contains('совет') || q.contains('рекомендац') || q.contains('tip') || q.contains('recommend') || q.contains('улучш') || q.contains('improve')) {
      final recs = store.recommendations;
      if (recs.isEmpty) return context.tr('ai.no_recommendations');
      return recs.map((r) => '• ${context.tr(r.titleKey, namedArgs: r.titleArgs)}\n  ${context.tr(r.descKey, namedArgs: r.descArgs)}').join('\n\n');
    }

    if (q.contains('привет') || q.contains('hello') || q.contains('здравствуй') || q.contains('hi')) {
      final total = store.accounts.fold(0.0, (s, a) => s + a.balance);
      return '${context.tr('ai.greeting')}\n\n${context.tr('ai.summary', namedArgs: {'balance': store.fmt(total), 'income': store.fmt(monthIncome), 'expense': store.fmt(monthExpense)})}';
    }

    return context.tr('ai.help');
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
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _chip(context.tr('ai.cmd_balance'), Icons.account_balance_wallet),
                                _chip(context.tr('ai.cmd_income'), Icons.trending_up),
                                _chip(context.tr('ai.cmd_expenses'), Icons.trending_down),
                                _chip(context.tr('ai.cmd_categories'), Icons.category),
                                _chip(context.tr('ai.cmd_goals'), Icons.flag),
                                _chip(context.tr('ai.cmd_budgets'), Icons.bar_chart),
                                _chip(context.tr('ai.cmd_tips'), Icons.lightbulb_outline),
                              ],
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final isUser = msg['role'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                              decoration: BoxDecoration(
                                color: isUser ? AppColors.primary : AppColors.cardFor(context),
                                borderRadius: BorderRadius.circular(12).copyWith(
                                  bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                                  bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                                ),
                              ),
                              child: Text(msg['text'] ?? '',
                                style: TextStyle(color: isUser ? Colors.white : AppColors.textFor(context), fontSize: 14),
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
                      child: Row(
                        children: [
                          _actionChip(context.tr('ai.cmd_balance'), () => _quickCommand(context.tr('ai.cmd_balance'))),
                          _actionChip(context.tr('ai.cmd_income'), () => _quickCommand(context.tr('ai.cmd_income'))),
                          _actionChip(context.tr('ai.cmd_expenses'), () => _quickCommand(context.tr('ai.cmd_expenses'))),
                          _actionChip(context.tr('ai.cmd_tips'), () => _quickCommand(context.tr('ai.cmd_tips'))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: context.tr('ai_assistant.placeholder'),
                              filled: true, fillColor: AppColors.cardFor(context),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.send, color: AppColors.primary),
                          onPressed: _send,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, IconData icon) {
    return GestureDetector(
      onTap: () => _quickCommand(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
