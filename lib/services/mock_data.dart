import '../models/account.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/goal.dart';
import '../models/operation.dart';
import '../models/recommendation.dart';
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
  Category(id: 'c1', name: 'Продукты', type: 'expense', icon: 'shopping_cart', color: '#F59E0B'),
  Category(id: 'c2', name: 'Транспорт', type: 'expense', icon: 'directions_car', color: '#3B82F6'),
  Category(id: 'c3', name: 'Кафе и рестораны', type: 'expense', icon: 'restaurant', color: '#EF4444'),
  Category(id: 'c4', name: 'Жильё', type: 'expense', icon: 'home', color: '#8B5CF6'),
  Category(id: 'c5', name: 'Развлечения', type: 'expense', icon: 'movie', color: '#EC4899'),
  Category(id: 'c6', name: 'Здоровье', type: 'expense', icon: 'favorite', color: '#14B8A6'),
  Category(id: 'c7', name: 'Связь и интернет', type: 'expense', icon: 'wifi', color: '#0EA5E9'),
  Category(id: 'c8', name: 'Одежда', type: 'expense', icon: 'checkroom', color: '#A855F7'),
  Category(id: 'c9', name: 'Зарплата', type: 'income', icon: 'payments', color: '#16A34A'),
  Category(id: 'c10', name: 'Фриланс', type: 'income', icon: 'laptop', color: '#22C55E'),
  Category(id: 'c11', name: 'Подарки', type: 'income', icon: 'card_giftcard', color: '#10B981'),
  Category(id: 'c12', name: 'Инвестиции', type: 'income', icon: 'trending_up', color: '#059669'),
  Category(id: 'c13', name: 'Накопления', type: 'expense', icon: 'savings', color: '#7C3AED'),
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
  Operation(id: 'o1', type: 'expense', amount: 2350, date: _iso(0), accountId: 'a2', categoryId: 'c1', comment: 'Пятёрочка', tagIds: ['t1']),
  Operation(id: 'o2', type: 'expense', amount: 450, date: _iso(0), accountId: 'a1', categoryId: 'c2', comment: 'Метро'),
  Operation(id: 'o3', type: 'income', amount: 95000, date: _iso(1), accountId: 'a3', categoryId: 'c9', comment: 'Зарплата', tagIds: ['t2']),
  Operation(id: 'o4', type: 'expense', amount: 1200, date: _iso(1), accountId: 'a2', categoryId: 'c3', comment: 'Кофейня'),
  Operation(id: 'o5', type: 'transfer', amount: 20000, date: _iso(2), accountId: 'a3', toAccountId: 'a4', comment: 'Перевод на накопления'),
  Operation(id: 'o6', type: 'expense', amount: 35000, date: _iso(3), accountId: 'a3', categoryId: 'c4', comment: 'Аренда квартиры'),
  Operation(id: 'o7', type: 'expense', amount: 890, date: _iso(4), accountId: 'a2', categoryId: 'c7', comment: 'Связь'),
  Operation(id: 'o8', type: 'expense', amount: 3200, date: _iso(5), accountId: 'a2', categoryId: 'c5', comment: 'Кино и боулинг', tagIds: ['t1']),
  Operation(id: 'o9', type: 'income', amount: 18000, date: _iso(6), accountId: 'a2', categoryId: 'c10', comment: 'Проект на фрилансе', tagIds: ['t2']),
  Operation(id: 'o10', type: 'expense', amount: 5400, date: _iso(7), accountId: 'a2', categoryId: 'c8', comment: 'Одежда'),
];

final mockBudgets = [
  Budget(id: 'b1', name: 'Продукты', categoryId: 'c1', limit: 20000, spent: 9800),
  Budget(id: 'b2', name: 'Транспорт', categoryId: 'c2', limit: 5000, spent: 2200),
  Budget(id: 'b3', name: 'Коммуналка', categoryId: 'c3', limit: 8000, spent: 6100),
  Budget(id: 'b4', name: 'Здоровье', categoryId: 'c6', limit: 4000, spent: 0),
  Budget(id: 'b5', name: 'Одежда', categoryId: 'c8', limit: 3000, spent: 1200),
];

final mockGoals = [
  Goal(id: 'g1', title: 'Подушка безопасности', targetAmount: 300000, currentAmount: 180000, deadline: '2026-12-31', icon: 'shield', color: '#16A34A', monthlyRecommendation: 17142),
  Goal(id: 'g2', title: 'Отпуск в Сочи', targetAmount: 120000, currentAmount: 45000, deadline: '2026-08-15', icon: 'beach_access', color: '#0EA5E9', monthlyRecommendation: 25000),
  Goal(id: 'g3', title: 'Новый ноутбук', targetAmount: 150000, currentAmount: 150000, deadline: '2026-05-01', icon: 'laptop', color: '#7C3AED', monthlyRecommendation: 0),
];

final mockRecommendations = [
  Recommendation(id: 'r1', title: 'Расходы на кафе превышают план', description: 'За последние 3 месяца вы тратите на кафе на 25% больше, чем планировали.', type: 'optimization', severity: 'medium'),
  Recommendation(id: 'r2', title: 'Высокий уровень фиксированных расходов', description: 'Аренда занимает 38% от дохода. Рекомендуется не более 30%.', type: 'risk', severity: 'high'),
  Recommendation(id: 'r3', title: 'Отличный прогресс по подушке безопасности', description: 'Вы накопили уже 60% от цели.', type: 'tip', severity: 'low'),
  Recommendation(id: 'r4', title: 'Настройте автоперевод на цели', description: 'Регулярные автоматические переводы помогают достигать целей на 30% быстрее.', type: 'tip', severity: 'low'),
];
