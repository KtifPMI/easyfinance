class Recommendation {
  final String id;
  final String title;
  final String description;
  final String type;
  final String severity;
  final String? actionType;
  final String? actionPayload;
  final Map<String, String> titleArgs;
  final Map<String, String> descArgs;

  Recommendation({
    required this.id,
    required this.title,
    required this.description,
    this.type = 'tip',
    this.severity = 'low',
    this.actionType,
    this.actionPayload,
    this.titleArgs = const {},
    this.descArgs = const {},
  });

  String get titleKey => 'recommend.$_baseId.title';
  String get descKey => 'recommend.$_baseId.desc';

  String get _baseId {
    if (id.startsWith('b_overspent_')) return 'budget_overspent';
    if (id.startsWith('b_near_')) return 'budget_near_limit';
    if (id.startsWith('no_budget_')) return 'no_budget';
    if (id.startsWith('idle_cash_')) return 'idle_cash';
    if (id.startsWith('goal_close_')) return 'goal_close';
    if (id == 'dining_freq') return 'dining_frequent';
    if (id.startsWith('expense_trend_')) return 'expense_trend';
    if (id.startsWith('income_trend_')) return 'income_trend';
    if (id.startsWith('category_spike_')) return 'category_spike';
    if (id.startsWith('recurring_')) return 'recurring_expense';
    if (id.startsWith('weekend_')) return 'weekend_splurge';
    if (id.startsWith('dominant_')) return 'single_category';
    if (id.startsWith('large_cash_')) return 'large_cash';
    if (id == 'top_cats') return 'expense_structure';
    if (id == 'no_emergency') return 'emergency_fund';
    if (id == 'goal_pacing_slow') return 'goal_pacing';
    return id;
  }
}
