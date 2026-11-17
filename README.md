# EasyFinance

Мобильное приложение для учёта личных финансов. Работает с аккаунтом на [easyfinance.ru](https://easyfinance.ru).

## Что умеет

- счета, доходы, расходы и переводы, теги и фильтры
- бюджеты и финансовые цели
- календарь плановых платежей
- отчёты и графики по месяцам
- курсы валют и основная валюта
- работа из локального кеша без сети

## Запуск

```bash
flutter pub get
flutter run
```

## Сборка

```bash
flutter build apk --release
```

Файлы с ключами (`android/key.properties`, `android/key.jks`, `lib/config.dart`) в репозиторий не входят.

## Релизы

- push в `main` запускает сборку APK (`Build APK`)
- тег вида `v1.41.153+313` запускает сборку APK и AAB для Google Play (`Release APK + AAB`)
