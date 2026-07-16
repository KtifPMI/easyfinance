import 'package:flutter_test/flutter_test.dart';
import 'package:easyfinance_app/models/goal.dart';
import 'package:easyfinance_app/services/currency_rate_service.dart';

void main() {
  test('parses targets API date and account fields', () {
    final goal = Goal.fromJson({
      'id': '102749006',
      'title': 'Мебель',
      'amount': '5000000.00',
      'amount_done': '5000.00',
      'currency_id': '1',
      'account_id': '501385016',
      'date_begin': '2026-07-16',
      'date_end': '2026-12-31',
      'visible': '1',
      'done': '0',
    });

    expect(goal.startDate, '2026-07-16');
    expect(goal.deadline, '2026-12-31');
    expect(goal.accountId, '501385016');
    expect(goal.currentAmount, 5000);
  });

  test('normalizes zero target dates to empty values', () {
    final goal = Goal.fromJson({
      'id': '1',
      'title': 'Без даты',
      'amount': '100',
      'date_begin': '0000-00-00',
      'date_end': '0000-00-00',
    });

    expect(goal.startDate, isEmpty);
    expect(goal.deadline, isEmpty);
  });

  test('converts CBR rates through RUB', () {
    final rates = {'RUB': 1.0, 'USD': 80.0, 'EUR': 90.0};
    expect(CurrencyRateService.convert(10, 'USD', 'RUB', rates), 800);
    expect(CurrencyRateService.convert(90, 'EUR', 'USD', rates), 101.25);
  });
}
