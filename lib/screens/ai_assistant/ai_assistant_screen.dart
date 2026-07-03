import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/operation.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';
import '../../utils/format.dart';

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

  String _analyze(String query, FinanceStore store) {
    final q = query.toLowerCase();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    bool inRange(Operation o) {
      final d = DateTime.tryParse(o.date);
      return d != null && !d.isBefore(monthStart) && !d.isAfter(monthEnd);
    }

    final monthIncome = store.operations.where((o) => o.type == 'income' && inRange(o)).fold(0.0, (s, o) => s + o.amount);
    final monthExpense = store.operations.where((o) => o.type == 'expense' && inRange(o)).fold(0.0, (s, o) => s + o.amount);

    if (q.contains('баланс') || q.contains('баланс') || (q.contains('сколько') && q.contains('денег')) || q.contains('balance') || q.contains('money')) {
      final total = store.accounts.fold(0.0, (s, a) => s + a.balance);
      return 'Общий баланс по всем счетам: ${formatMoney(total)}\n\n${store.accounts.map((a) => '• ${a.name}: ${formatMoney(a.balance)}').join('\n')}';
    }

    if ((q.contains('трат') || q.contains('расход') || q.contains('spent') || q.contains('expense')) && q.contains('категори')) {
      final catName = store.categories.where((c) => q.contains(c.name.toLowerCase())).firstOrNull;
      if (catName != null) {
        final total = store.operations.where((o) => o.categoryId == catName.id && o.type == 'expense').fold(0.0, (s, o) => s + o.amount);
        return 'Всего потрачено по категории «${catName.name}»: ${formatMoney(total)}.';
      }
      final totals = <String, double>{};
      for (final o in store.operations.where((o) => o.type == 'expense')) {
        final cat = store.categories.where((c) => c.id == o.categoryId).firstOrNull;
        if (cat != null) totals.update(cat.name, (v) => v + o.amount, ifAbsent: () => o.amount);
      }
      final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return 'Расходы по категориям:\n${sorted.map((e) => '• ${e.key}: ${formatMoney(e.value)}').join('\n')}';
    }

    if ((q.contains('доход') || q.contains('заработ') || q.contains('income') || q.contains('earn')) && (q.contains('сколько') || q.contains('how much'))) {
      return 'Доход за этот месяц: ${formatMoney(monthIncome)}.\nРасход за этот месяц: ${formatMoney(monthExpense)}.\nОстаток: ${formatMoney(monthIncome - monthExpense)}.';
    }

    if (q.contains('счёт') || q.contains('счет') || q.contains('account')) {
      final total = store.accounts.fold(0.0, (s, a) => s + a.balance);
      return 'У вас ${store.accounts.length} счет(ов) на общую сумму ${formatMoney(total)}.\n\n${store.accounts.map((a) => '• ${a.name}: ${formatMoney(a.balance)}').join('\n')}';
    }

    if (q.contains('цел') || q.contains('goal')) {
      if (store.goals.isEmpty) return 'У вас пока нет целей. Создайте первую в разделе «План».';
      return store.goals.map((g) {
        final pct = g.targetAmount > 0 ? (g.currentAmount / g.targetAmount * 100).round() : 0;
        return '• ${g.title}: ${formatMoney(g.currentAmount)} из ${formatMoney(g.targetAmount)} ($pct%)${g.isCompleted ? ' ✅' : ''}';
      }).join('\n');
    }

    if (q.contains('бюджет') || q.contains('budget')) {
      final budgets = store.budgets;
      if (budgets.isEmpty) return 'У вас нет бюджетов. Создайте первый в разделе «План».';
      return budgets.map((b) {
        final cat = store.categories.where((c) => c.id == b.categoryId).firstOrNull;
        final name = b.name ?? cat?.name ?? '';
        final pct = b.limit > 0 ? (b.spent / b.limit * 100).round() : 0;
        return '• $name: ${formatMoney(b.spent)} из ${formatMoney(b.limit)} ($pct%)';
      }).join('\n');
    }

    if (q.contains('совет') || q.contains('рекомендац') || q.contains('tip') || q.contains('recommend') || q.contains('улучш') || q.contains('improve')) {
      final recs = store.recommendations;
      return recs.map((r) => '• ${r.title} — ${r.description}').join('\n\n');
    }

    if (q.contains('привет') || q.contains('hello') || q.contains('здравствуй') || q.contains('hi')) {
      final total = store.accounts.fold(0.0, (s, a) => s + a.balance);
      return 'Привет! 👋 Я ваш финансовый ассистент.\n\nОбщий баланс: ${formatMoney(total)}\nДоход за месяц: ${formatMoney(monthIncome)}\nРасход за месяц: ${formatMoney(monthExpense)}\n\nСпросите меня о расходах, доходах, счетах, целях, бюджетах или советах.';
    }

    return 'Я понимаю вопросы о:\n\n'
      '💰 «Какой баланс?» / «Мои счета»\n'
      '📊 «Расходы по категориям» / «Сколько я потратил на еду?»\n'
      '📈 «Доход за месяц»\n'
      '🎯 «Мои цели»\n'
      '📋 «Бюджеты»\n'
      '💡 «Советы» / «Что улучшить?»';
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
                          final isUser = msg['role'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                              decoration: BoxDecoration(
                                color: isUser ? AppColors.primary : AppColors.card,
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
                decoration: BoxDecoration(color: AppColors.background, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))]),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration: InputDecoration(
                          hintText: context.tr('ai_assistant.placeholder'),
                          filled: true, fillColor: AppColors.card,
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
              ),
            ],
          ),
        );
      },
    );
  }
}
