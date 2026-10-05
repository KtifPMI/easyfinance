import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/operation.dart';
import '../models/user.dart';

/// Переводчик из easy_localization (`tr`). Демо-данные собираются функциями,
/// а не константами, чтобы при смене языка их можно было пересобрать.
typedef Tr = String Function(String key);

const demoUserId = 'u1';

const _accountNameKeys = <String, String>{
  'a1': 'demo.acc.cash',
  'a2': 'demo.acc.card',
  'a3': 'demo.acc.bank',
  'a4': 'demo.acc.savings',
};

const _categoryNameKeys = <String, String>{
  '551145658': 'demo.cat.car',
  '551145659': 'demo.cat.bank_service',
  '551145661': 'demo.cat.household',
  '551145663': 'demo.cat.leisure',
  '551145664': 'demo.cat.utilities',
  '551145665': 'demo.cat.medical',
  '551145666': 'demo.cat.taxes',
  '551145667': 'demo.cat.education',
  '551145668': 'demo.cat.clothes',
  '551145669': 'demo.cat.food',
  '551145670': 'demo.cat.gifts',
  '551145671': 'demo.cat.transport',
  '551145673': 'demo.cat.other_personal',
  '551145674': 'demo.cat.work_expenses',
  '551145675': 'demo.cat.comms',
  '551145676': 'demo.cat.insurance',
  '551145677': 'demo.cat.selfcare',
  '551145678': 'demo.cat.personal_income',
  '551145679': 'demo.cat.investment_income',
  '551145672': 'demo.cat.other_income',
  '551145680': 'demo.cat.undefined_expense',
  '551145681': 'demo.cat.transfer',
  '551145682': 'demo.cat.undefined_income',
  '551145683': 'demo.cat.bad_habits',
  '551145685': 'demo.cat.loan_interest',
  '551145686': 'demo.cat.investment_expense',
};

const _budgetNameKeys = <String, String>{
  'bi1': 'demo.cat.personal_income',
  'bi2': 'demo.cat.other_income',
  'b1': 'demo.cat.food',
  'b2': 'demo.cat.transport',
  'b3': 'demo.cat.utilities',
  'b4': 'demo.cat.medical',
  'b5': 'demo.cat.clothes',
  'b6': 'demo.cat.leisure',
  'b7': 'demo.cat.comms',
};

const _budgetLimits = <String, double>{
  'bi1': 95000, 'bi2': 10000, 'b1': 30000, 'b2': 5000, 'b3': 8000,
  'b4': 5000, 'b5': 5000, 'b6': 10000, 'b7': 3000,
};

const _budgetCategoryIds = <String, String>{
  'bi1': '551145678', 'bi2': '551145672', 'b1': '551145669', 'b2': '551145671',
  'b3': '551145664', 'b4': '551145665', 'b5': '551145668', 'b6': '551145663',
  'b7': '551145675',
};

/// Ключ перевода имени демо-счёта; null — счёт не демо-шный (пользовательский).
String? demoAccountNameKey(String id) => _accountNameKeys[id];

/// Ключ перевода имени демо-категории; null — категория пользовательская.
String? demoCategoryNameKey(String id) => _categoryNameKeys[id];

/// Ключ перевода имени демо-бюджета; null — бюджет пользовательский.
String? demoBudgetNameKey(String id) => _budgetNameKeys[id];

/// Ключ перевода комментария демо-операции. Комментарии у операций
/// генерируются по шаблону (см. [_buildMockOperations]), поэтому здесь
/// хранится соответствие «суффикс id → ключ», а сами операции помнят ключ
/// в [Operation.tags] поле demo-комментария через [demoCommentKeys].
const _opCommentKeysBySuffix = <String, String>{
  'zp': 'demo.op.salary',
  'bonus': 'demo.op.bonus',
  'rent': 'demo.op.rent',
  'food': 'demo.op.groceries',
  'trans': 'demo.op.transport',
  'com': 'demo.op.comms',
  'fun': 'demo.op.leisure',
  'care': 'demo.op.selfcare',
  'clothes': 'demo.op.clothes',
  'recent-1': 'demo.op.freelance',
  'recent-2': 'demo.op.grocery_store',
  'recent-3': 'demo.op.metro',
  'recent-4': 'demo.op.clothes',
  'recent-5': 'demo.op.cinema',
  'recent-6': 'demo.op.transfer_savings',
};

/// Ключ перевода комментария операции по её id, либо null для реальных данных.
String? demoCommentKey(String opId) {
  if (opId.startsWith('recent-')) return _opCommentKeysBySuffix[opId];
  final dash = opId.lastIndexOf('-');
  if (dash < 0 || !opId.startsWith('m')) return null;
  return _opCommentKeysBySuffix[opId.substring(dash + 1)];
}

User buildMockUser(Tr tr) => User(
      id: demoUserId,
      name: tr('demo.user'),
      email: 'demo@easyfinance.ru',
      currency: 'RUB',
    );

List<Account> buildMockAccounts(Tr tr) => [
      Account(id: 'a1', name: tr('demo.acc.cash'), balance: 12500, icon: 'cash', color: '#16A34A'),
      Account(id: 'a2', name: tr('demo.acc.card'), balance: 84300, icon: 'credit_card', color: '#FFD700'),
      Account(id: 'a3', name: tr('demo.acc.bank'), balance: 213400, icon: 'account_balance', color: '#1565C0'),
      Account(id: 'a4', name: tr('demo.acc.savings'), balance: 350000, icon: 'savings', color: '#7C3AED'),
    ];

List<Category> buildMockCategories(Tr tr) => [
      Category(id: '551145658', name: tr('demo.cat.car'), type: 'expense', icon: 'directions_car', color: '#EF4444'),
      Category(id: '551145659', name: tr('demo.cat.bank_service'), type: 'expense', icon: 'account_balance', color: '#3B82F6'),
      Category(id: '551145661', name: tr('demo.cat.household'), type: 'expense', icon: 'home', color: '#8B5CF6'),
      Category(id: '551145663', name: tr('demo.cat.leisure'), type: 'expense', icon: 'movie', color: '#EC4899'),
      Category(id: '551145664', name: tr('demo.cat.utilities'), type: 'expense', icon: 'receipt', color: '#F59E0B'),
      Category(id: '551145665', name: tr('demo.cat.medical'), type: 'expense', icon: 'favorite', color: '#14B8A6'),
      Category(id: '551145666', name: tr('demo.cat.taxes'), type: 'expense', icon: 'receipt_long', color: '#71717A'),
      Category(id: '551145667', name: tr('demo.cat.education'), type: 'expense', icon: 'school', color: '#6366F1'),
      Category(id: '551145668', name: tr('demo.cat.clothes'), type: 'expense', icon: 'checkroom', color: '#A855F7'),
      Category(id: '551145669', name: tr('demo.cat.food'), type: 'expense', icon: 'restaurant', color: '#F59E0B'),
      Category(id: '551145670', name: tr('demo.cat.gifts'), type: 'expense', icon: 'card_giftcard', color: '#10B981'),
      Category(id: '551145671', name: tr('demo.cat.transport'), type: 'expense', icon: 'directions_bus', color: '#3B82F6'),
      Category(id: '551145673', name: tr('demo.cat.other_personal'), type: 'expense', icon: 'more_horiz', color: '#6B7280'),
      Category(id: '551145674', name: tr('demo.cat.work_expenses'), type: 'expense', icon: 'work', color: '#4B5563'),
      Category(id: '551145675', name: tr('demo.cat.comms'), type: 'expense', icon: 'wifi', color: '#0EA5E9'),
      Category(id: '551145676', name: tr('demo.cat.insurance'), type: 'expense', icon: 'security', color: '#6366F1'),
      Category(id: '551145677', name: tr('demo.cat.selfcare'), type: 'expense', icon: 'spa', color: '#EC4899'),
      Category(id: '551145678', name: tr('demo.cat.personal_income'), type: 'income', icon: 'payments', color: '#16A34A'),
      Category(id: '551145679', name: tr('demo.cat.investment_income'), type: 'income', icon: 'trending_up', color: '#059669'),
      Category(id: '551145672', name: tr('demo.cat.other_income'), type: 'income', icon: 'attach_money', color: '#10B981'),
      Category(id: '551145680', name: tr('demo.cat.undefined_expense'), type: 'expense', icon: 'help_outline', color: '#9CA3AF'),
      Category(id: '551145681', name: tr('demo.cat.transfer'), type: 'transfer', icon: 'swap_horiz', color: '#6B7280'),
      Category(id: '551145682', name: tr('demo.cat.undefined_income'), type: 'income', icon: 'help_outline', color: '#9CA3AF'),
      Category(id: '551145683', name: tr('demo.cat.bad_habits'), type: 'expense', icon: 'warning', color: '#DC2626'),
      Category(id: '551145685', name: tr('demo.cat.loan_interest'), type: 'expense', icon: 'credit_card', color: '#DC2626'),
      Category(id: '551145686', name: tr('demo.cat.investment_expense'), type: 'expense', icon: 'trending_down', color: '#DC2626'),
    ];

Operation _mkOp(String id, String type, double amount, DateTime d, String accountId, String categoryId, String comment, {String? toAccountId}) {
  return Operation(
    id: id,
    type: type,
    amount: amount,
    date: d.toIso8601String(),
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    comment: comment,
  );
}

/// Демо-данные за последние 12 месяцев: в каждом месяце — зарплата и набор
/// типовых расходов с вариацией по месяцам, чтобы в отчётах/графиках были
/// "живые" столбики доходов, расходов и чистого дохода.
List<Operation> buildMockOperations(Tr tr) => _buildMockOperations(tr);

List<Operation> _buildMockOperations(Tr tr) {
  final now = DateTime.now();
  final ops = <Operation>[];
  // Индекс i=0 — текущий месяц, i=11 — самый старый (12 месяцев назад).
  const salary = <double>[95000, 94000, 96000, 91000, 98000, 89000, 92000, 88000, 95000, 87000, 90000, 85000];
  const rent = <double>[30000, 32000, 32000, 31000, 32000, 33000, 30000, 32000, 31000, 32000, 32000, 33000];
  const food = <double>[15000, 18000, 16000, 17000, 15000, 19000, 17000, 16000, 18000, 17000, 16000, 18000];
  const trans = <double>[2000, 3500, 2800, 3200, 3000, 3800, 2600, 3400, 3000, 2800, 3200, 3000];
  const com = <double>[2000, 2500, 2200, 2600, 2400, 2800, 2300, 2500, 2400, 2300, 2500, 2600];
  const fun = <double>[0, 4500, 12000, 5500, 6500, 8000, 7000, 5500, 6500, 10000, 11000, 9000];
  const care = <double>[1500, 2500, 2000, 3000, 2500, 2800, 2200, 2600, 2400, 2300, 2600, 2500];
  const clothes = <double>[0, 8000, 0, 0, 15000, 0, 0, 9000, 0, 0, 0, 12000];
  const bonus = <double>[0, 0, 12000, 0, 0, 0, 30000, 0, 0, 0, 0, 0];

  for (var i = 11; i >= 0; i--) {
    final m = DateTime(now.year, now.month - i, 1);
    final daysIn = DateTime(m.year, m.month + 1, 0).day;
    DateTime day(int d) => DateTime(m.year, m.month, d.clamp(1, daysIn), 12);
    final suf = '$i';
    ops.add(_mkOp('m$suf-zp', 'income', salary[i], day(1), 'a3', '551145678', tr('demo.op.salary')));
    if (bonus[i] > 0) {
      ops.add(_mkOp('m$suf-bonus', 'income', bonus[i], day(20), 'a3', '551145678', tr('demo.op.bonus')));
    }
    ops.add(_mkOp('m$suf-rent', 'expense', rent[i], day(3), 'a3', '551145661', tr('demo.op.rent')));
    ops.add(_mkOp('m$suf-food', 'expense', food[i], day(10), 'a2', '551145669', tr('demo.op.groceries')));
    ops.add(_mkOp('m$suf-trans', 'expense', trans[i], day(12), 'a1', '551145671', tr('demo.op.transport')));
    ops.add(_mkOp('m$suf-com', 'expense', com[i], day(15), 'a2', '551145675', tr('demo.op.comms')));
    if (fun[i] > 0) {
      ops.add(_mkOp('m$suf-fun', 'expense', fun[i], day(20), 'a2', '551145663', tr('demo.op.leisure')));
    }
    ops.add(_mkOp('m$suf-care', 'expense', care[i], day(25), 'a2', '551145677', tr('demo.op.selfcare')));
    if (clothes[i] > 0) {
      ops.add(_mkOp('m$suf-clothes', 'expense', clothes[i], day(18), 'a2', '551145668', tr('demo.op.clothes')));
    }
  }
  // Актуальные операции текущего месяца, чтобы список не был "пустым"
  final today = DateTime(now.year, now.month, now.day);
  String tIso(int daysAgo) => today.subtract(Duration(days: daysAgo)).toIso8601String();
  ops.add(_mkOp('recent-1', 'income', 18000, DateTime.parse(tIso(6)), 'a2', '551145678', tr('demo.op.freelance')));
  ops.add(_mkOp('recent-2', 'expense', 2350, DateTime.parse(tIso(0)), 'a2', '551145669', tr('demo.op.grocery_store')));
  ops.add(_mkOp('recent-3', 'expense', 450, DateTime.parse(tIso(0)), 'a1', '551145671', tr('demo.op.metro')));
  ops.add(_mkOp('recent-4', 'expense', 3800, DateTime.parse(tIso(4)), 'a2', '551145668', tr('demo.op.clothes')));
  ops.add(_mkOp('recent-5', 'expense', 3200, DateTime.parse(tIso(5)), 'a2', '551145663', tr('demo.op.cinema')));
  ops.add(_mkOp('recent-6', 'transfer', 20000, DateTime.parse(tIso(2)), 'a3', '551145681', tr('demo.op.transfer_savings'), toAccountId: 'a4'));
  return ops;
}

List<Budget> buildMockBudgets(Tr tr) => [
      for (final id in _budgetNameKeys.keys)
        Budget(id: id, name: tr(_budgetNameKeys[id]!), categoryId: _budgetCategoryIds[id]!, limit: _budgetLimits[id]!, spent: 0),
    ];
