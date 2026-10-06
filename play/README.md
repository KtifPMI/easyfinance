# Подготовка к публикации в Google Play

Всё необходимое для сборки и публикации App Bundle уже настроено в репозитории.

## Что готово

- `pubspec.yaml` — версия `1.0.0+133` (`versionName=1.0.0`, `versionCode=133`).
- `.github/workflows/release.yml` при пуше тега `v*` собирает два флейвора:
  - **`direct`** → `build/app/outputs/flutter-apk/app-direct-release.apk` —
    APK для прямой раздачи с GitHub; в нём есть `REQUEST_INSTALL_PACKAGES`,
    без которого не работает встроенный апдейтер;
  - **`play`** → `build/app/outputs/bundle/playRelease/app-play-release.aab` —
    App Bundle для Google Play; `REQUEST_INSTALL_PACKAGES` в нём **нет**;
  - оба файла прикрепляются к GitHub-релизу.
- Подпись AAB та же, что и APK: CI генерирует `android/key.properties` из секрета
  `RELEASE_KEYSTORE`. При первой заливке в Play этот ключ станет *upload-ключом*
  (Play App Signing), дальше релизным ключом управляет Google.
- `play/metadata/ru-RU` и `play/metadata/en-US` — тексты листинга
  (title / short_description / full_description), готовые к копированию в консоль
  (или к загрузке через fastlane).

## Вариант A. Ручная заливка (рекомендую для первого релиза)

1. Запушить тег `v1.0.0` (CI соберёт APK + AAB и создаст GitHub-релиз).
2. Скачать `app-play-release.aab` из релиза:
   `https://github.com/KtifPMI/easyfinance/releases/tag/v1.0.0`
3. В [Play Console](https://play.google.com/console/) создать приложение,
   включить Play App Signing и загрузить AAB.
4. Заполнить листинг: скопировать тексты из `play/metadata/*`, добавить
   иконку (`assets/images/logo.png` / `android/app/src/main/res/mipmap-*`),
   **2–8 скриншотов телефона**, графику-заставку (feature graphic),
   и **ссылку на политику конфиденциальности** (политику нужно разместить
   на сайте и указать URL).
5. Пройти контент-рейтинг, отправить на review.

## Обновления приложения

В приложении уже реализован собственный механизм обновлений: `update_service.dart`
раз в сутки (и при ручной проверке) обращается к
`api.github.com/repos/KtifPMI/easyfinance/releases/latest`, берёт **APK** из
последнего релиза и предлагает скачать/установить его. Поэтому **канал
обновлений — это GitHub-релиз с APK**, а не Google Play.

Чтобы выпустить обновление, достаточно запушить новый тег `vX.Y.Z`: CI соберёт
APK (и AAB) и создаст релиз, а приложение само предложит апдейт пользователям.
Авто-загрузка AAB в Play из CI **не используется** — Play нужен только для
первичной публикации/листинга. AAB из релиза загружается в консоль вручную
(вариант A).

## Что ещё нужно подготовить вручную

- **Скриншоты** приложения (Play их не генерирует).
- **Политика конфиденциальности** (обязательна; особенно т.к. приложение
  использует камеру/MLKit и сеть). Размести на сайте и укажи URL в консоли.
- **Обновления:** работают через встроенный GitHub-апдейтер (`update_service.dart`),
  который качает APK из GitHub-релиза. Дополнительных плагинов (`in_app_update`)
  не требуется. Апдейт получают **только** пользователи, установившие APK
  напрямую: `update_service._installedFromPlay()` отключает апдейтер, если
  приложение установлено из Google Play.

## Флейворы

В `android/app/build.gradle` объявлены два флейвора (`flavorDimensions`:
`distribution`), отличающиеся составом манифеста:

- `play` — без `REQUEST_INSTALL_PACKAGES`. Из него собирается AAB для Google
  Play: разрешение попало бы в обязательную декларацию, а основная
  функциональность финансового приложения — не управление установками.
- `direct` — с `REQUEST_INSTALL_PACKAGES` (единственная строка в
  `android/app/src/direct/AndroidManifest.xml`). Из него собирается APK
  для GitHub.

Оба флейвора используют один и тот же `applicationId` = `com.EasyFinance`,
`namespace`, `versionCode` и `versionName`. Локальная проверка:

```bash
flutter build appbundle --release --flavor play
flutter build apk --release --flavor direct
flutter build apk --release   # соберёт оба, как build_apk.yml
```

## Пакет приложения

- `applicationId` = `com.EasyFinance` (задан в `android/app/build.gradle`).
  Так требует запись в Play Console — пакет нельзя менять после первой
  публикации приложения, поэтому Play — источник истины.
- iOS `PRODUCT_BUNDLE_IDENTIFIER` = `com.EasyFinance`
  (`ios/Runner.xcodeproj/project.pbxproj`) — намеренно совпадает с Android.
- `namespace` в `build.gradle` остаётся `com.easyfinance.app` — это пакет
  Kotlin/R-классов, по нему разрешается `.MainActivity` в манифесте.
  namespace и `applicationId` независимы, и это нормально; менять его
  не нужно и даже вредно: придётся переносить `MainActivity.kt`.

