import 'package:flutter/material.dart';
import '../models/category.dart';

/// Top-level system category names mapped to logical icons.
const Map<String, IconData> _rootIcons = {
  'автомобиль': Icons.directions_car,
  'банковское обслуживание': Icons.account_balance,
  'дети': Icons.child_friendly,
  'домашнее хозяйство': Icons.home,
  'домашние животные': Icons.pets,
  'досуг и отдых': Icons.sports_esports,
  'коммунальные платежи': Icons.bolt,
  'медицина': Icons.local_hospital,
  'налоги, сборы и услуги': Icons.receipt_long,
  'образование': Icons.school,
  'одежда, обувь, аксессуары': Icons.checkroom,
  'питание': Icons.restaurant,
  'подарки, материальная помощь': Icons.card_giftcard,
  'проезд, транспорт': Icons.directions_bus,
  'прочие доходы': Icons.attach_money,
  'прочие личные расходы': Icons.more_horiz,
  'расходы по работе': Icons.work,
  'связь, тв и интернет': Icons.wifi,
  'страхование': Icons.shield,
  'уход за собой': Icons.spa,
  'персональные доходы': Icons.payments,
  'инвестиционный доход': Icons.trending_up,
  'инвестиционный расход': Icons.trending_down,
  'проценты по кредитам и займам': Icons.percent,
  'вредные привычки': Icons.warning,
  'мотоцикл': Icons.two_wheeler,
  'перевод': Icons.swap_horiz,
  'не определена. для расходов': Icons.help_outline,
  'не определена. для доходов': Icons.help_outline,
};

/// Ordered keyword groups used as a fallback for custom/unknown categories.
const List<(String, IconData)> _keywordIcons = [
  ('инвестицион', Icons.trending_up),
  ('дивиденд', Icons.trending_up),
  ('акци', Icons.show_chart),
  ('мото', Icons.two_wheeler),
  ('авто', Icons.directions_car),
  ('машин', Icons.directions_car),
  ('топлив', Icons.local_gas_station),
  ('стоянк', Icons.directions_car),
  ('парковк', Icons.directions_car),
  ('гараж', Icons.garage),
  ('животн', Icons.pets),
  ('корм', Icons.pets),
  ('ветеринар', Icons.pets),
  ('дет', Icons.child_friendly),
  ('авиа', Icons.flight),
  ('поезд', Icons.train),
  ('метро', Icons.subway),
  ('такси', Icons.local_taxi),
  ('автобус', Icons.directions_bus),
  ('транспорт', Icons.directions_bus),
  ('билет', Icons.confirmation_number),
  ('еда', Icons.restaurant),
  ('продукт', Icons.local_grocery_store),
  ('ресторан', Icons.restaurant),
  ('кафе', Icons.local_cafe),
  ('обед', Icons.restaurant),
  ('питание', Icons.restaurant),
  ('алкоголь', Icons.liquor),
  ('сигарет', Icons.smoking_rooms),
  ('табак', Icons.smoking_rooms),
  ('вредн', Icons.warning),
  ('лекарств', Icons.medication),
  ('аптек', Icons.local_pharmacy),
  ('врач', Icons.medical_services),
  ('больниц', Icons.local_hospital),
  ('стомат', Icons.medical_services),
  ('медиц', Icons.local_hospital),
  ('одежд', Icons.checkroom),
  ('обувь', Icons.checkroom),
  ('аксессуар', Icons.watch),
  ('школ', Icons.school),
  ('универ', Icons.school),
  ('обучен', Icons.school),
  ('образован', Icons.school),
  ('учебник', Icons.menu_book),
  ('книг', Icons.menu_book),
  ('интернет', Icons.wifi),
  ('телефон', Icons.phone_android),
  ('связь', Icons.wifi),
  ('тв', Icons.tv),
  ('театр', Icons.theater_comedy),
  ('концерт', Icons.music_note),
  ('кино', Icons.movie),
  ('игр', Icons.sports_esports),
  ('развлечен', Icons.celebration),
  ('спорт', Icons.sports_soccer),
  ('фитнес', Icons.fitness_center),
  ('отдых', Icons.beach_access),
  ('досуг', Icons.sports_esports),
  ('хобби', Icons.palette),
  ('страхов', Icons.shield),
  ('подарк', Icons.card_giftcard),
  ('мебель', Icons.chair),
  ('уборо', Icons.cleaning_services),
  ('ремонт', Icons.home_repair_service),
  ('квартир', Icons.home),
  ('хозяйств', Icons.home),
  ('быт', Icons.home),
  ('дом', Icons.home),
  ('банк', Icons.account_balance),
  ('комисс', Icons.account_balance),
  ('налог', Icons.receipt_long),
  ('зарплат', Icons.payments),
  ('бонус', Icons.card_giftcard),
  ('преми', Icons.card_giftcard),
  ('работ', Icons.work),
  ('кредит', Icons.percent),
  ('займ', Icons.percent),
  ('процент', Icons.percent),
  ('подписк', Icons.subscriptions),
  ('сбережен', Icons.savings),
  ('накоплен', Icons.savings),
];

/// Resolves a logical Material icon for a category.
///
/// The icon is derived from the top-level parent category (system categories),
/// so every subcategory (e.g. all automotive ones) shares the same icon.
IconData categoryIconFor(Category category, {List<Category>? allCategories}) {
  final root = _rootCategory(category, allCategories ?? const <Category>[]);
  final byRoot = _rootIcons[root.name.trim().toLowerCase()];
  if (byRoot != null) return byRoot;

  final name = category.name.trim().toLowerCase();
  for (final (keyword, icon) in _keywordIcons) {
    if (name.contains(keyword)) return icon;
  }
  return Icons.category;
}

Category _rootCategory(Category category, List<Category> all) {
  var current = category;
  final seen = <String>{};
  while (current.parentId != null && current.parentId!.isNotEmpty && seen.add(current.id)) {
    Category? parent;
    for (final c in all) {
      if (c.id == current.parentId) {
        parent = c;
        break;
      }
    }
    if (parent == null) break;
    current = parent;
  }
  return current;
}
