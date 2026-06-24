class User {
  final String id;
  final String name;
  final String email;
  final String currency;
  final String plan;
  final String? avatarUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.currency = 'RUB',
    this.plan = 'free',
    this.avatarUrl,
  });
}
