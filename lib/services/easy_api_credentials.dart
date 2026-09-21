/// Креды идентификации приложения в easyApi (для нативной регистрации).
///
/// Это статичная пара code/password из server: sf/apps/easyApi/config/app.yml
/// (android: code=2, password=kUyTg3n3n5nH). Она же зашита во всех старых
/// мобильных клиентах и передаётся как GET-параметры `app_id`/`app_pass`.
class EasyApiCredentials {
  static const String registerUrl = 'https://api.easyfinance.ru/registration.xml';
  static const String appId = '2';
  static const String appPass = 'kUyTg3n3n5nH';
}