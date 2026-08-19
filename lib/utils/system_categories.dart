/// Canonical (system) categories from the EasyFinance server, keyed by type.
///
/// A root category (no parent) must be linked to one of these via `system_id`.
/// A child category inherits `system_id` from its parent. The numeric keys are
/// the real server `system_id` values (verified against categories.get).
///
/// Note: this list is only a fallback for brand-new users. In practice the
/// screen builds the picker from the user's own root categories (which already
/// carry the correct `system_id` -> name mapping), so the names below are kept
/// in sync with the server but rarely used.
const Map<String, Map<int, String>> systemCategories = {
  'expense': {
    1: 'Автомобиль',
    2: 'Банковское обслуживание',
    3: 'Автомобиль',
    4: 'Домашнее хозяйство',
    5: 'Домашние животные',
    6: 'Досуг и отдых',
    7: 'Коммунальные платежи',
    8: 'Медицина',
    9: 'Налоги, сборы и услуги',
    10: 'Образование',
    11: 'Одежда, обувь, аксессуары',
    12: 'Питание',
    13: 'Подарки, материальная помощь',
    14: 'Проезд, транспорт',
    15: 'Проценты по кредитам и займам',
    17: 'Прочие личные расходы',
    18: 'Расходы по работе',
    19: 'Связь, ТВ и интернет',
    20: 'Страхование',
    21: 'Уход за собой',
    30: 'Не определена. Для расходов',
    36: 'Вредные привычки',
    40: 'Мотоцикл',
    41: 'Инвестиционный расход',
  },
  'income': {
    16: 'Прочие доходы',
    22: 'Персональные доходы',
    23: 'Инвестиционный доход',
    32: 'Не определена. Для доходов',
  },
};
