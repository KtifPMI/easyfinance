# Google Play: отказ по FOREGROUND_SERVICE_DATA_SYNC

Статус: **выполнено, проверено сборкой AAB/APK**
Версия: 1.41.146+306 (play flavor, release)

---

## 1. Отказ

> FOREGROUND_SERVICE_DATA_SYNC. Это разрешение можно запрашивать, только если
> в приложении выполняются задачи, заметные для пользователя, когда он не
> взаимодействует с приложением напрямую.
> Либо убрать функцию, либо нужно видео с показом функциональности.

Play предложил два пути: убрать функциональность **или** предоставить видео
для Permissions Declaration Form (ревью — до нескольких недель).

Выбран третий, корректный путь: **убрать разрешение, не трогая функциональность** —
потому что разрешение приложением фактически не используется.

---

## 2. Откуда берётся разрешение

Разрешение **не объявлено в коде приложения**. Его подмешивает плагин
`workmanager` версии 0.9.3:

| Источник | Что даёт |
|---|---|
| `workmanager_android-0.9.3/android/src/main/AndroidManifest.xml:5,7,8` | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `FOREGROUND_SERVICE_SHORT_SERVICE` |
| там же, строки 17–22 | `foregroundServiceType="dataSync\|shortService"` на `androidx.work.impl.foreground.SystemForegroundService` |
| `androidx.work:work-runtime-2.11.2.aar` | только базовый `FOREGROUND_SERVICE` |

Проверено сканированием: во **всех 113 AAR** в Gradle-кэше и во **всех
манифестах** Pub-кэша `FOREGROUND_SERVICE_DATA_SYNC` объявляет **только**
`workmanager_android`. Других источников нет.

Функция появилась именно в 0.9.3 — `workmanager-0.9.3/CHANGELOG.md:5`:

```
## 0.9.3
  - **FEAT**(android): long-running workers via foreground service (#698).
```

В `pubspec.yaml:34` указано `workmanager: ^0.9.0+3`, и `pub get` подтянул
0.9.3. Ранее собранные AAB (версии ниже 1.41.146) эти разрешения не
содержали — поэтому отказ пришёл именно сейчас.

### Цепочка доказательства, что разрешение не используется

1. Единственная задача — `lib/services/notification_service.dart:161`
   `registerPeriodicTask('dailyCheck', ...)`, параметр `foregroundServiceConfig`
   **не передаётся** (nullable, по умолчанию `null`).
2. `workmanager_android/.../InputDataUtils.kt:50-51` — конфиг пишется в input
   data **только если не null**.
3. `workmanager_android/.../BackgroundWorker.kt:66-72` — `setForegroundAsync()`
   (запуск foreground-service) вызывается **только если конфиг не null**.

Итог: `SystemForegroundService` **никогда не стартует**. Задежность `dailyCheck`
идёт обычным `androidx.work.impl.background.systemjob.SystemJobService`
(JobScheduler), уведомления шлёт `flutter_local_notifications` — им разрешения
на FGS не нужны.

Дополнительно проверено:

- в `lib/` нет ни одного вызова `startForegroundService` /
  `foregroundServiceTypes` (поиск по всему Dart-коду — 0 совпадений);
- `flutter_local_notifications` метод `startForegroundService` экспортирует
  (`platform_flutter_local_notifications.dart:276`), но приложение его не
  вызывает, а сам `ForegroundService` **не объявлен** в манифесте плагина
  (там только `VIBRATE` и `POST_NOTIFICATIONS`) — то есть и путь не активен;
- `setExpedited` плагин вызывает только при `outOfQuotaPolicy`
  (`WorkManagerUtils.kt:189`), а `registerPeriodicTask` этот параметр не
  передаёт — expedited-work тоже нет.

**Вывод: «убрать функцию» не нужно.** Функция напоминаний («Платежи завтра»,
«Цель близка!» в 10:00) работает без FGS и после правки — поведение не
меняется ни на единицу.

---

## 3. Правка

Файл: `android/app/src/main/AndroidManifest.xml`

Добавлены три строки `tools:node="remove"` (тот же приём, что уже применён
для `READ_MEDIA_*` в этом же файле, строки 9–11 — он проверен в проде):

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" tools:node="remove"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" tools:node="remove"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SHORT_SERVICE" tools:node="remove"/>
```

Удалены **все три**, а не только `DATA_SYNC`:

- `DATA_SYNC` — требование Play;
- `SHORT_SERVICE` — та же категория, риск аналогичного отказа;
- `FOREGROUND_SERVICE` (базовый) — приложение не запускает ни один
  foreground-service, оставлять его незачем.

Сервис `SystemForegroundService` в манифесте оставлен как есть: он не стартует,
а объявление сервиса Play-политикой не сканируется (сканируются
`<uses-permission>`).

---

## 4. Проверка (выполнена)

```
flutter build appbundle --flavor play --release   → 76.1 MB, EXIT=0
flutter build apk      --flavor play --release   → 95.1 MB, EXIT=0
```

**AAB** (`build/app/outputs/bundle/playRelease/app-play-release.aab`),
манифест `base/manifest/AndroidManifest.xml` (protobuf, строки UTF-8):

```
FOREGROUND_SERVICE_DATA_SYNC -> 0
FOREGROUND_SERVICE_SHORT_SERVICE -> 0
FOREGROUND_SERVICE -> 0
```

Оставшиеся разрешения в AAB:
`INTERNET, CAMERA, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, VIBRATE,
READ_EXTERNAL_STORAGE (maxSdk 32), WAKE_LOCK, ACCESS_NETWORK_STATE,
BIND_JOB_SERVICE, DUMP, com.EasyFinance.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`

**APK** (`aapt2 dump permissions`):

```
package: com.EasyFinance
uses-permission: name='android.permission.INTERNET'
uses-permission: name='android.permission.CAMERA'
uses-permission: name='android.permission.POST_NOTIFICATIONS'
uses-permission: name='android.permission.RECEIVE_BOOT_COMPLETED'
uses-permission: name='android.permission.VIBRATE'
uses-permission: name='android.permission.READ_EXTERNAL_STORAGE' maxSdkVersion='32'
uses-permission: name='android.permission.WAKE_LOCK'
uses-permission: name='android.permission.ACCESS_NETWORK_STATE'
permission: com.EasyFinance.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
uses-permission: name='com.EasyFinance.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'
```

FGS-разрешений нет.

**Механизм напоминаний на месте** (сведённый манифест `playRelease`):

- `androidx.work.impl.background.systemjob.SystemJobService` — есть;
- `androidx.work.impl.background.systemalarm.RescheduleReceiver` — есть;
- `RECEIVE_BOOT_COMPLETED` — есть (перепланирование после перезагрузки);
- `flutter_local_notifications` (`VIBRATE`, `POST_NOTIFICATIONS`) — есть.

---

## 5. Что нужно проверить на устройстве (нет подключённого Android)

`adb devices` — устройств нет, поэтому on-device тест не выполнялся.
Перед загрузкой в Play, на любом Android-телефоне:

1. Установить свежий `app-play-release.apk`.
2. Открыть приложение, разрешить уведомления, завести плановый платёж/цель.
3. Полностью закрыть приложение (свайп из списка недавних).
4. Дождаться 10:00 или перевести время вперёд — должно прийти уведомление.
5. Перезагрузить телефон — после перезагрузки задача должна перепланироваться
   (`RescheduleReceiver`), уведомление на следующий день приходит.

Ожидаемый результат: всё работает **идентично** текущей версии, т.к. FGS и
раньше не запускался.

---

## 6. Откат

```powershell
cd C:\Users\lehag\OneDrive\Desktop\gitlab_repos\easyfinance_app
git checkout -- android/app/src/main/AndroidManifest.xml
flutter build appbundle --flavor play --release
```

Откат возвращает ровно то состояние, в котором отказ Play получен.
Ничего больше правка не затрагивает: ни Dart-кода, ни ресурсов, ни зависимостей.

---

## 7. Если Play всё равно запросит видео (вариант B)

Правка убирает триггер отказа — разрешений в AAB нет, декларировать нечего.
Но если потребуется Permissions Declaration Form на другое разрешение
(например, `CAMERA`), сценарий видео для фоновой функциональности:

1. Установка приложения, вход в аккаунт.
2. Создание планового платежа / цели с напоминанием.
3. Полное закрытие приложения (свайп из недавних).
4. Перевод времени устройства на 10:00 следующего дня.
5. Включение экрана — появляется уведомление «Платежи завтра» / «Цель близка!»
   **без открытия приложения**.

Формат: YouTube (ссылка в форме) или облачное хранилище (mp4), тестовый
логин/пароль для ревьюера. Ревью — до нескольких недель.

---

## 8. Смежные факты (на будущее)

- `workmanager` 0.9.3 → 0.10.x доступен (`pub outdated` показал
  `0.10.10`); обновление может изменить манифест плагина — после любого
  обновления зависимостей **перепроверять** `aapt2 dump permissions`.
- Flutter предупреждает: `package_info_plus` и `workmanager_android`
  применяют KGP — в будущих версиях Flutter сборка может сломаться.
- `targetSdk = 36`: если FGS когда-либо реально понадобится, на Android 15+
  действует лимит `dataSync` — 6 часов суммарно за 24 часа. Это ещё одна
  причина не тянуть FGS «на всякий случай».
