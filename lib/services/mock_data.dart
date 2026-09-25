import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/operation.dart';
import '../models/user.dart';

final mockUser = User(id: 'u1', name: 'Алексей Иванов', email: 'demo@easyfinance.ru', currency: 'RUB');

final mockAccounts = [
  Account(id: 'a1', name: 'Наличные', balance: 12500, icon: 'cash', color: '#16A34A'),
  Account(id: 'a2', name: 'Карта Тинькофф', balance: 84300, icon: 'credit_card', color: '#FFD700'),
  Account(id: 'a3', name: 'Сбербанк', balance: 213400, icon: 'account_balance', color: '#1565C0'),
  Account(id: 'a4', name: 'Накопительный счёт', balance: 350000, icon: 'savings', color: '#7C3AED'),
];

final mockCategories = [
  Category(id: '551145658', name: 'Автомобиль', type: 'expense', icon: 'directions_car', color: '#EF4444'),
  Category(id: '551145659', name: 'Банковское обслуживание', type: 'expense', icon: 'account_balance', color: '#3B82F6'),
  Category(id: '551145661', name: 'Домашнее хозяйство', type: 'expense', icon: 'home', color: '#8B5CF6'),
  Category(id: '551145663', name: 'Досуг и отдых', type: 'expense', icon: 'movie', color: '#EC4899'),
  Category(id: '551145664', name: 'Коммунальные платежи', type: 'expense', icon: 'receipt', color: '#F59E0B'),
  Category(id: '551145665', name: 'Медицина', type: 'expense', icon: 'favorite', color: '#14B8A6'),
  Category(id: '551145666', name: 'Налоги, сборы и услуги', type: 'expense', icon: 'receipt_long', color: '#71717A'),
  Category(id: '551145667', name: 'Образование', type: 'expense', icon: 'school', color: '#6366F1'),
  Category(id: '551145668', name: 'Одежда, обувь, аксессуары', type: 'expense', icon: 'checkroom', color: '#A855F7'),
  Category(id: '551145669', name: 'Питание', type: 'expense', icon: 'restaurant', color: '#F59E0B'),
  Category(id: '551145670', name: 'Подарки, материальная помощь', type: 'expense', icon: 'card_giftcard', color: '#10B981'),
  Category(id: '551145671', name: 'Проезд, транспорт', type: 'expense', icon: 'directions_bus', color: '#3B82F6'),
  Category(id: '551145673', name: 'Прочие личные расходы', type: 'expense', icon: 'more_horiz', color: '#6B7280'),
  Category(id: '551145674', name: 'Расходы по работе', type: 'expense', icon: 'work', color: '#4B5563'),
  Category(id: '551145675', name: 'Связь, ТВ и интернет', type: 'expense', icon: 'wifi', color: '#0EA5E9'),
  Category(id: '551145676', name: 'Страхование', type: 'expense', icon: 'security', color: '#6366F1'),
  Category(id: '551145677', name: 'Уход за собой', type: 'expense', icon: 'spa', color: '#EC4899'),
  Category(id: '551145678', name: 'Персональные доходы', type: 'income', icon: 'payments', color: '#16A34A'),
  Category(id: '551145679', name: 'Инвестиционный доход', type: 'income', icon: 'trending_up', color: '#059669'),
  Category(id: '551145672', name: 'Прочие доходы', type: 'income', icon: 'attach_money', color: '#10B981'),
  Category(id: '551145680', name: 'Не определена. Для расходов', type: 'expense', icon: 'help_outline', color: '#9CA3AF'),
  Category(id: '551145681', name: 'Перевод', type: 'transfer', icon: 'swap_horiz', color: '#6B7280'),
  Category(id: '551145682', name: 'Не определена. Для доходов', type: 'income', icon: 'help_outline', color: '#9CA3AF'),
  Category(id: '551145683', name: 'Вредные привычки', type: 'expense', icon: 'warning', color: '#DC2626'),
  Category(id: '551145685', name: 'Проценты по кредитам и займам', type: 'expense', icon: 'credit_card', color: '#DC2626'),
  Category(id: '551145686', name: 'Инвестиционный расход', type: 'expense', icon: 'trending_down', color: '#DC2626'),
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
final mockOperations = _buildMockOperations();

List<Operation> _buildMockOperations() {
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
    ops.add(_mkOp('m$suf-zp', 'income', salary[i], day(1), 'a3', '551145678', 'Зарплата'));
    if (bonus[i] > 0) {
      ops.add(_mkOp('m$suf-bonus', 'income', bonus[i], day(20), 'a3', '551145678', 'Премия'));
    }
    ops.add(_mkOp('m$suf-rent', 'expense', rent[i], day(3), 'a3', '551145661', 'Аренда квартиры'));
    ops.add(_mkOp('m$suf-food', 'expense', food[i], day(10), 'a2', '551145669', 'Продукты'));
    ops.add(_mkOp('m$suf-trans', 'expense', trans[i], day(12), 'a1', '551145671', 'Транспорт'));
    ops.add(_mkOp('m$suf-com', 'expense', com[i], day(15), 'a2', '551145675', 'Связь и интернет'));
    if (fun[i] > 0) {
      ops.add(_mkOp('m$suf-fun', 'expense', fun[i], day(20), 'a2', '551145663', 'Досуг'));
    }
    ops.add(_mkOp('m$suf-care', 'expense', care[i], day(25), 'a2', '551145677', 'Уход за собой'));
    if (clothes[i] > 0) {
      ops.add(_mkOp('m$suf-clothes', 'expense', clothes[i], day(18), 'a2', '551145668', 'Одежда'));
    }
  }
  // Актуальные операции текущего месяца, чтобы список не был "пустым"
  final today = DateTime(now.year, now.month, now.day);
  String tIso(int daysAgo) => today.subtract(Duration(days: daysAgo)).toIso8601String();
  ops.add(_mkOp('recent-1', 'income', 18000, DateTime.parse(tIso(6)), 'a2', '551145678', 'Проект на фрилансе'));
  ops.add(_mkOp('recent-2', 'expense', 2350, DateTime.parse(tIso(0)), 'a2', '551145669', 'Пятёрочка'));
  ops.add(_mkOp('recent-3', 'expense', 450, DateTime.parse(tIso(0)), 'a1', '551145671', 'Метро'));
  ops.add(_mkOp('recent-4', 'expense', 3800, DateTime.parse(tIso(4)), 'a2', '551145668', 'Одежда'));
  ops.add(_mkOp('recent-5', 'expense', 3200, DateTime.parse(tIso(5)), 'a2', '551145663', 'Кино и боулинг'));
  ops.add(_mkOp('recent-6', 'transfer', 20000, DateTime.parse(tIso(2)), 'a3', '551145681', 'Перевод на накопления', toAccountId: 'a4'));
  return ops;
}

final mockBudgets = [
  Budget(id: 'bi1', name: 'Персональные доходы', categoryId: '551145678', limit: 95000, spent: 0),
  Budget(id: 'bi2', name: 'Прочие доходы', categoryId: '551145672', limit: 10000, spent: 0),
  Budget(id: 'b1', name: 'Питание', categoryId: '551145669', limit: 30000, spent: 0),
  Budget(id: 'b2', name: 'Проезд, транспорт', categoryId: '551145671', limit: 5000, spent: 0),
  Budget(id: 'b3', name: 'Коммунальные платежи', categoryId: '551145664', limit: 8000, spent: 0),
  Budget(id: 'b4', name: 'Медицина', categoryId: '551145665', limit: 5000, spent: 0),
  Budget(id: 'b5', name: 'Одежда, обувь, аксессуары', categoryId: '551145668', limit: 5000, spent: 0),
  Budget(id: 'b6', name: 'Досуг и отдых', categoryId: '551145663', limit: 10000, spent: 0),
  Budget(id: 'b7', name: 'Связь, ТВ и интернет', categoryId: '551145675', limit: 3000, spent: 0),
];


