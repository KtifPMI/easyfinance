import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/operation.dart';
import '../models/tag.dart';
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

final mockTags = [
  Tag(id: 't1', name: 'Семья'),
  Tag(id: 't2', name: 'Работа'),
  Tag(id: 't3', name: 'Отпуск'),
  Tag(id: 't4', name: 'Срочно'),
];

String _iso(int daysAgo) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  return d.toIso8601String();
}

final mockOperations = [
  Operation(id: 'o1', type: 'expense', amount: 2350, date: _iso(0), accountId: 'a2', categoryId: '551145669', comment: 'Пятёрочка', tagIds: ['t1']),
  Operation(id: 'o2', type: 'expense', amount: 450, date: _iso(0), accountId: 'a1', categoryId: '551145671', comment: 'Метро'),
  Operation(id: 'o3', type: 'income', amount: 95000, date: _iso(1), accountId: 'a3', categoryId: '551145678', comment: 'Зарплата', tagIds: ['t2']),
  Operation(id: 'o4', type: 'expense', amount: 1200, date: _iso(1), accountId: 'a2', categoryId: '551145663', comment: 'Кофейня'),
  Operation(id: 'o5', type: 'transfer', amount: 20000, date: _iso(2), accountId: 'a3', toAccountId: 'a4', comment: 'Перевод на накопления'),
  Operation(id: 'o6', type: 'expense', amount: 35000, date: _iso(3), accountId: 'a3', categoryId: '551145661', comment: 'Аренда квартиры'),
  Operation(id: 'o7', type: 'expense', amount: 890, date: _iso(4), accountId: 'a2', categoryId: '551145675', comment: 'Связь'),
  Operation(id: 'o8', type: 'expense', amount: 3200, date: _iso(5), accountId: 'a2', categoryId: '551145663', comment: 'Кино и боулинг', tagIds: ['t1']),
  Operation(id: 'o9', type: 'income', amount: 18000, date: _iso(6), accountId: 'a2', categoryId: '551145678', comment: 'Проект на фрилансе', tagIds: ['t2']),
  Operation(id: 'o10', type: 'expense', amount: 5400, date: _iso(7), accountId: 'a2', categoryId: '551145668', comment: 'Одежда'),
];

final mockBudgets = [
  Budget(id: 'b1', name: 'Питание', categoryId: '551145669', limit: 30000, spent: 0),
  Budget(id: 'b2', name: 'Проезд, транспорт', categoryId: '551145671', limit: 5000, spent: 0),
  Budget(id: 'b3', name: 'Коммунальные платежи', categoryId: '551145664', limit: 8000, spent: 0),
  Budget(id: 'b4', name: 'Медицина', categoryId: '551145665', limit: 5000, spent: 0),
  Budget(id: 'b5', name: 'Одежда, обувь, аксессуары', categoryId: '551145668', limit: 5000, spent: 0),
  Budget(id: 'b6', name: 'Досуг и отдых', categoryId: '551145663', limit: 10000, spent: 0),
  Budget(id: 'b7', name: 'Связь, ТВ и интернет', categoryId: '551145675', limit: 3000, spent: 0),
];


