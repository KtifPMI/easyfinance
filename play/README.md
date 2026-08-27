# Подготовка к публикации в Google Play

Всё необходимое для сборки и публикации App Bundle уже настроено в репозитории.

## Что готово

- `pubspec.yaml` — версия `1.0.0+133` (`versionName=1.0.0`, `versionCode=133`).
- `.github/workflows/release.yml` при пуше тега `v*` собирает:
  - **APK** (`build/app/outputs/flutter-apk/*.apk`) — для прямой раздачи;
  - **AAB** (`build/app/outputs/bundle/release/*.aab`) — для Google Play;
  - оба файла прикрепляются к GitHub-релизу.
- Подпись AAB та же, что и APK: CI генерирует `android/key.properties` из секрета
  `RELEASE_KEYSTORE`. При первой заливке в Play этот ключ станет *upload-ключом*
  (Play App Signing), дальше релизным ключом управляет Google.
- `play/metadata/ru-RU` и `play/metadata/en-US` — тексты листинга
  (title / short_description / full_description), готовые к копированию в консоль
  (или к загрузке через fastlane).

## Вариант A. Ручная заливка (рекомендую для первого релиза)

1. Запушить тег `v1.0.0` (CI соберёт APK + AAB и создаст GitHub-релиз).
2. Скачать `app-release.aab` из релиза:
   `https://github.com/KtifPMI/easyfinance/releases/tag/v1.0.0`
3. В [Play Console](https://play.google.com/console/) создать приложение,
   включить Play App Signing и загрузить AAB.
4. Заполнить листинг: скопировать тексты из `play/metadata/*`, добавить
   иконку (`assets/images/logo.png` / `android/app/src/main/res/mipmap-*`),
   **2–8 скриншотов телефона**, графику-заставку (feature graphic),
   и **ссылку на политику конфиденциальности** (политику нужно разместить
   на сайте и указать URL).
5. Пройти контент-рейтинг, отправить на review.

## Вариант B. Авто-загрузка в Play из CI

Добавь в *Settings → Secrets* репозитория секрет:

- `PLAY_SERVICE_ACCOUNT_JSON` — JSON service-аккаунта (с правами
  «Play Console → Admin» / доступом к редакции приложения). Создать в
  Google Cloud → IAM → Service Accounts → создать ключ JSON.

При наличии этого секрета шаг «Upload to Google Play» в `release.yml` сработает
автоматически и загрузит AAB в трек `internal` со статусом `draft`
(чтобы ты мог проверить его в консоли до раскатки). Track/status можно поменять
в `release.yml`.

## Что ещё нужно подготовить вручную

- **Скриншоты** приложения (Play их не генерирует).
- **Политика конфиденциальности** (обязательна; особенно т.к. приложение
  использует камеру/MLKit и сеть). Размести на сайте и укажи URL в консоли.
- **Обновления внутри приложения:** сейчас проверка обновлений, видимо, идёт по
  GitHub-релизам. Для дистрибуции через Play рекомендуется переключить механизм
  на плагин `in_app_update` (Play Core), иначе пользователи Play не будут
  получать предложение обновиться из магазина.

## Пакет приложения

- `applicationId` = `com.easyfinance.app` (задан в `android/app/build.gradle`).
  Менять нельзя после первой публикации в Play.
