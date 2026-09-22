# Нативный логин и мастер первого входа (EasyFinance)

План перехода с WebView-входа на нативную авторизацию (`grant_type=password`) и
нативный мастер первого входа. Записан по фактам ревизии сервера.

---

## 0. Статус

### Уже сделано
- **password grant включён и проверен** на сервере (см. §3). Возвращает
  `access_token`; `users.get` с токеном работает.
- **`users.delete`** (удаление аккаунта) — отдельная фича, тоже сделана на сервере
  и отгружена в приложении (не часть мастера).

### Что решено по мастеру
- Серверная схема: **Вариант A** — новые методы `master.get` / `master.set` / `master.finish`.
- Показываем шаги: **1 (валюта), 2 (категории), 3 (бюджет + цель), 5 («Как начать учёт»)**, затем finish.
- Пропускаем: **4** (нет синхронизации с Google/календарём), **6** (мобильное приложение —
  мы уже в приложении), **7** (нет банков).
- **8 и 9 не показываются**: на сайте у профиля последний шаг — 7, дальше цепочка кончается.
- **Фаза 0 выполнена**: цепочка шагов и процентовка бюджета/цели подтверждены дампом
  БД и чтением кода (§4.1.1–4.1.2).
- **Фаза 1 (сервер) — ВЫПОЛНЕНО и проверено на боевом сервере (21.09.2026)**:
  `master.get` / `master.set` / `master.finish` залиты (контракт — §4.2,
  ответы проверены живыми запросами; `finished` + `already_completed`; бюджет и
  цель заведены в БД — см. §4.2).
- По ходу живых тестов исправлены 3 точки с зависимостью от web-`sfUser`
  (в API-контексте его нет): `IS_IFRAME_SESSION` в get-цепочке,
  `myUser::getUserSettingsRecord` в `RegistrationModel`, `myUser::getUserRecord`
  в `TargetForm` (цель теперь пишется напрямую через модель `Target` +
  `TargetAccount`; счёт привязывается только первый свободный).
- Мастер-файлы: `MasterData.php` (локальная копия — `C:\Users\lehag\AppData\Local\Temp\opencode\`) + `apiMasterValidator.php`.
- **Фаза 2 (нативный логин) — ВЫПОЛНЕНО и выпущено (v1.41.119+279)**.
- **Регистрация — ВЫПОЛНЕНО и выпущено (v1.41.120+280)**.
- **Фаза 3 (нативный мастер в Flutter) — ВЫПОЛНЕНО (готово к релизу v1.41.121+281)**:
  экраны онбординга, guard после входа, серверный фикс `is_master_completed=false`
  для easyApi-регистрации, локали 8 файлов.

---

## 1. Целевой flow

1. Нативный экран: Login + Password.
2. `grant_type=password` → сервер отвечает `302` с `access_token` в `Location`.
3. Токен в `FlutterSecureStorage`.
4. Все запросы — с `access_token`.
5. `master.get` → если `is_active && !is_master_completed` → нативный мастер.
6. Шаги 1→2→3→5, финал `master.finish`, затем main.

---

## 2. Как сайт решает, показывать ли мастер

- Глобальный тумблер: `app_project_first_time_entrance_master_enabled`
  (`/var/www/easyfinance.ru/sf/config/app.yml:56` → сейчас `true`), кладётся в
  контекст как `isMasterActive` фильтром
  `apps/frontend/lib/filter/isMasterCompletedFilter.class.php`.
- Личный флаг: `user_settings.is_master_completed`.
  - если пользователя/настроек нет → считается пройденным (`true`);
  - иначе — `$userSettings->getIsMasterCompleted()`.
- Условие показа (`apps/frontend/templates/_res.php:44`):
  `is_active && !is_master_completed`. Тогда же сервер отдаёт `master_chain`
  (`FirstTimeEntranceMasterSettingTable::getMasterChainByProfileType($account_type)`)
  и карты переходов.
- Флаг: сбрасывается в `false` в `ResetUserData.class.php:336`, ставится `true`
  в `executeFinishMaster()` (`actions.class.php:293`); при регистрации через API —
  сразу `true`, если у приложения `DISABLE_FEM`, иначе `false` (`UserData.php:286`).

### 2.1 Единый источник истины — `user_settings.is_master_completed`

- `master.get` / `master.finish` читают и пишут **ту же строку `user_settings`**
  (по `user id`), что и сайт — без кэшей.
- Мастер пройден на сайте → приложение видит флаг `true`, мастер не показывается;
  `master.finish` из приложения → сайт перестаёт показывать web-мастер.
- Если строки `user_settings` нет → сайт считает мастер пройденным (`true`);
  поведение API — такое же (либо создать строку).
- `DISABLE_FEM` у приложения → флаг сразу `true` (мастер нигде не показывается).
- При регистрации через `users.post` флаг ставится сразу (по `DISABLE_FEM`).
- Проверить заодно: текущий флаг у тестового Goldman (`account_type=company`).

---

## 3. Сервер: нативный логин (УЖЕ СДЕЛАНО)

### 3.1 Изменённые файлы
| Файл | Изменение |
|------|-----------|
| `lib/oauthServer/sfOAuth2Server.php` | добавлен `OAUTH2_GRANT_TYPE_USER_CREDENTIALS` в `getSupportedGrantTypes()`; реализован `checkUserCredentials($app_id, $username, $password)` → `UserTable::getUserByLoginAndPass($username, sha1($password))`, `setUserId()`, `TRUE`/`FALSE`; `grantAccessToken()` проксирует родителя |
| `lib/oauthServer/oauth2Lib/OAuth2.php` | в ветке `OAUTH2_GRANT_TYPE_USER_CREDENTIALS` снята заглушка `errorResponse(... INVALID_REQUEST ...)`; `username`/`password` из `$_GET` |
| `lib/model/doctrine/UserTable.class.php` | `getUserByLoginAndPass()`: `u.pass` → `u.password` (физическая колонка `user_pass` с алиасом `password`) |

Рядом с каждым файлом — бэкап `*.php.bak`. Пароль в БД — `sha1(plain)`.

### 3.2 Реальный формат запроса
```
GET https://api.easyfinance.ru/v2/
    ?app_id=APP_ID
    &grant_type=password
    &password=PASS
    &response_type=token
    &username=LOGIN
    &sig=SIG
```
- `sig = md5(secret_key + params)`, params — `app_id` первым, далее по алфавиту.
  Без `uid`.
- **Ответ — `302`, а не JSON:**
  `Location: https://api.easyfinance.ru/v2/result?access_token=...&expires_in=...`
  (тот же приём, что в `exchangeCodeForToken` — запрос с `followRedirects = false`).

```bash
APP_ID="7e65ca8e482d55ad7ad31476d7b33dc64a7d0f60"
SECRET="e3df02801d7e7073a0d042f6a040aa043b9fc003"
PARAMS="app_id=${APP_ID}&grant_type=password&password=PASS&response_type=token&username=LOGIN"
SIG=$(printf '%s%s' "${SECRET}" "${PARAMS}" | md5sum | awk '{print $1}')
curl -s -D - -o /dev/null "https://api.easyfinance.ru/v2/?${PARAMS}&sig=${SIG}"
```

### 3.3 Credentials
| | app_id | secret |
|---|---|---|
| Flutter-приложение | `7e65ca8e482d55ad7ad31476d7b33dc64a7d0f60` | `e3df02801d7e7073a0d042f6a040aa043b9fc003` |

> Платформенные `app_id` 1–5 + `app_pass` для V2 password grant **не подходят**
> (`Invalid app_id`, код 57). Нужен hex-`app_id` приложения.

---

## 4. Сервер: нативный мастер (Вариант A)

### 4.1 Эталон — web-мастер
Контроллер `apps/frontend/modules/firstTimeEntranceMaster/actions/actions.class.php`.

| Шаг | Шаблон | Что сохраняет | В нативном мастере |
|---|---|---|---|
| 1 | `_startPage` | `currency_default` + `currency[]` (JSON) → `users.currency_id`, `users.currency_list` (serialize; плюс уже использованные валюты) | **делаем** |
| 2 | `_categories` | системные категории → `user_settings.has_automobile/has_motocycle/has_children/has_animals/pays_utilities`, `pays_renting` | **делаем** |
| 3 | `_budgetAndTarget` | `budgetTotalAmount`, `utilitiesAmount`, `rentingAmount`, `budget_start_day`, `targetAmount` (копятся в сессии, применяются на Finish) | **делаем** |
| 4 | `_calendarSettings` | SMS + Google Calendar → `profileActions::executeSaveReminders` | **пропуск** (нет синхронизации) |
| 5 | `_createOperation` | ничего (инфо) | **делаем** (инфо-экран) |
| 6 | `_mobile` | `mobile_application_id` | **пропуск** (мы уже в приложении) |
| 7 | `_downloadBanksAccount` | только рендер списка банков | **пропуск** (нет банков) |
| 8 | `_profileType` | `gender` → `users.account_type` | **не показывается** |
| 9 | `_businessCategories` | ничего | **не показывается** |
| — | `FinishMaster` | `setDefaultCategoriesByUserProfileType()` + `showHideCategoriesByMasterSettings()` + `addFirstBudgetAndTarget()` + `setIsMasterCompleted(true)` | **делаем** |

Содержимое шага 5 (инфо):
> Чтобы начать вести учёт: 1) создать счёт (наличные, банковский и т.д.);
> 2) добавить фактическую операцию (вручную, импорт из файла/выписки, автобанк).
> Ссылки: презентация, «как добавить счёт», «как добавить операцию»,
> «как добавить будущий доход/расход», «как добавить цель», «как добавить бюджет».

### 4.1.1 Подтверждено дампом БД (`firstTimeEntranceMaster_settings`)

| step_id | action_step_id | parent_action_step_id | name | is_active |
|---|---|---|---|---|
| 1 | **1** | — | Настройка валют | 1 |
| 2 | **8** | — | Выбор типа профиля | 1 |
| 3 | **2** | 8 | Настройка категорий | 1 |
| 4 | **3** | 2 | Первый бюджет и фин. цель | 1 |
| 5 | **5** | — | Страница обучающих видео | 1 |
| 6 | **4** | — | Настройки календаря | **0** |
| 7 | **6** | — | Выбор мобильного приложения | 1 |
| 8 | **7** | — | Привязка банковского счёта | 1 |

Маппинг `action_step_id` → шаг контроллера: `1`=валюты, `2`=категории,
`3`=бюджет+цель, `4`=календарь, `5`=обучающие видео, `6`=моб. приложение,
`7`=банки, `8`=выбор профиля (корень). `action_step_id=9` в таблице нет —
`Step9` (`businessCategories`) мёртвый.

Цепочки (`getMasterChainByProfileType`):
- **man/woman:** `[1, 2, 3, 5, 6, 7]` (шаг 4 неактивен, 8 исключён как корень).
- **company:** только корневые (`parent_action_step_id IS NULL`) → `[1, 5, 6, 7]`.

Нативный мастер (с учётом пропусков) = `[1, 2, 3, 5]`.

### 4.1.2 Процентовка бюджета и цель (finish)

- Ненулевые проценты из `default_category_budget_procent`: 5+10+15+10+7+3+10+5 = **65**
  (совпадает с делителем в формуле). Нулевые (28, 50, 89) — кастомные (аренда/коммуналка).
- Формула расходной категории: `sum = 0.85 * (budgetTotalAmount - renting - utilities) * procent / 65`.
- Кастом при `procent == 0`: дом = `rentingAmount`, коммуналка = `utilitiesAmount`.
- Доходные категории получают `budgetTotalAmount`.
- Бюджет сохраняется через `budgetActions::executeAdd`, `start = BudgetManager::getBudgetStartDate()`.
- Фин. цель: `title = 'Финансовая подушка'`, `type = TYPE_SAVE_MONEY`,
  `category = CATEGORY_ID_FINANCE_PILLOW`, `amount = targetAmount`,
  `start = сегодня`, `end = +30 месяцев`, `comment = ''`, привязка к первому
  доступному счёту; сохранение через `targetActions::executeProcessTarget`.
- Для `company` finish **не** вызывает `showHideCategories`/`addFirstBudgetAndTarget`.

> Креды БД для дампов — в `config/databases.yml` (не хранить в этом документе).

### 4.2 Новые серверные методы (Вариант A) — РЕАЛИЗОВАНО (Фаза 1)
- **`master.get`** → `{ is_active, is_master_completed, master_chain }`
  (`is_active` из `app_project_first_time_entrance_master_enabled`;
  `master_chain` из `FirstTimeEntranceMasterSettingTable::getMasterChainByProfileType`).
- **`master.set`** → сохраняет шаги 1 и 2 (`currency_default`, `currency_list`,
  `has_*`, `pays_renting`). Ответ `{ result: 'saved' }`.
- **`master.finish`** → принимает данные шага 3 (`budgetTotalAmount`,
  `utilitiesAmount`, `rentingAmount`, `targetAmount`), выполняет логику
  `FinishMaster` и ставит `is_master_completed = true`. Ответ
  `{ result: 'completed' }`; повтор → `{ result: 'already_completed' }` (без изменений).

Файлы и патчи (бэкапы `*.bak.MASTER`):
| Файл | Изменение |
|------|-----------|
| `apps/api/lib/apiDataClasses/MasterData.php` | **новый** — `get/set/finish`, запись в БД напрямую (как `users.delete`) |
| `apps/api/lib/requestValidateClasses/apiMasterValidator.php` | **новый** — `validateGet/Set/Finish` → `isValid=true`, бизнес-валидация в `MasterData` |
| `apps/api/lib/requestValidateClasses/RequestValidatorFactory.php` | + `validateMaster()` (ветка по `objectMethod`) |
| `apps/api/lib/apiDataClasses/allDataFactory.php` | + `getMasterData($user, $parameters)` |
| `apps/api/config/restConfig/queries_config.yml` | + `master.get` (пустой), `master.set`, `master.finish` |

`fields_mapping.yml` **не** правился — поля мастера в `users.get` не экспонируются,
выбран отдельный метод `master.get`.

**Архитектурное решение:** бюджет и цель НЕ идут через web-контроллеры
(`budgetActions::executeAdd` / `targetActions::executeProcessTarget` требуют
web-`sfUser` через `getUserRecord()` — в API не инстанцируются). Логика
реплицирована на уровне моделей внутри `MasterData`:
`BudgetCategoryTable::multipleUpdate/multipleInsert`,
`BudgetAdditionalEntityTable::multipleUpdate/multipleInsert`, `TargetForm`.
Формулы — §4.1.2. При пустом списке доступных счетов цель пропускается.
`currency_list` читается защитно (массив или serialized-строка).

Компания (`company`): finish делает пункты 1–2, **без** `showHideCategories` /
`addFirstBudgetAndTarget` (проверка по `account_type`).

> `users.set` (`syncUserSetForm.class.php`) сейчас умеет только `name`, `user_mail`,
> `sms_phone` — при Варианте A расширять его не обязательно. Если понадобится
> писать эти поля и вне мастера — вынести в `master.set`.

---

## 5. Flutter: нативный логин

- `lib/services/api_client.dart`:
  - `exchangePasswordForToken(login, password)` — GET с `followRedirects=false`,
    вытащить `access_token` из заголовка `Location`;
  - `loginWithPassword(...)` — обёртка + подпись `sig`.
- `lib/services/auth_service.dart` — сохранить `access_token`/`uid`, как сейчас.
- `lib/screens/auth/native_login_screen.dart` — **новый**: Login, Password, «Войти»,
  «Нет аккаунта?».
- `lib/screens/auth/login_screen.dart` — заменить WebView на нативный вход.
- `lib/screens/auth/oauth_webview_screen.dart` — fallback.

## 6. Flutter: нативный мастер

```
lib/screens/onboarding/
├── onboarding_screen.dart          # навигация по шагам, guard, финал
└── steps/
    ├── step_currency.dart          # 1: основная + доп. валюты (currencies.get)
    ├── step_categories.dart        # 2: системные категории (systemCategories.get)
    ├── step_budget_target.dart     # 3: бюджет + цель (локально → master.finish)
    └── step_start.dart             # 5: инфо «Как начать учёт» + ссылки
```

Запуск после логина:
```dart
final master = await apiClient.masterGet();
if (master.isActive && !master.isMasterCompleted) {
  Navigator.push(OnboardingScreen(chain: master.chain));
}
```

Запись:
- шаги 1,2 — `master.set`;
- шаг 3 — копится локально, уходит в `master.finish` (как в web — сессионные атрибуты);
- шаг 5 — без сохранения.

---

## 7. Фазы

- **Фаза 0 (без кода) — ВЫПОЛНЕНО:** дамп `firstTimeEntranceMaster_settings` и
  `default_category_budget_procent`, прочитан `addFirstBudgetAndTarget()`.
  См. §4.1.1–4.1.2. Нативный набор шагов — `[1,2,3,5]`.
- **Фаза 1 (сервер):** `master.get` / `master.set` / `master.finish` —
  **ВЫПОЛНЕНО и проверено** на боевом сервере (21.09.2026).
- **Фаза 2 (клиент, вход) — СЛЕДУЮЩАЯ:** `exchangePasswordForToken`,
  `loginWithPassword`, нативный экран логина.
- **Фаза 3 (клиент, мастер):** экраны 1,2,3,5 + финал, guard.
- **Фаза 4:** проверка на новом аккаунте (`is_master_completed=false`),
  бамп версии → тег → CI.

---

## 8. Файлы для изменений

### Сервер
| Файл | Изменение |
|------|-----------|
| `apps/api/config/restConfig/queries_config.yml` | новые `master.get`, `master.set`, `master.finish` |
| `apps/api/config/fieldsMapping/fields_mapping.yml` | поля мастера (`is_master_completed`, валюты, `has_*`, `pays_renting`) |
| `apps/api/lib/apiDataClasses/MasterData.php` | **новый** — чтение флага/цепочки, запись шагов, finish-логика |
| `apps/api/lib/requestValidateClasses/apiMasterValidator.php` | **новый** — валидация методов мастера |
| `apps/api/lib/apiDataClasses/UserData.php` | при необходимости — отдача флага |
| `apps/easyApi/modules/registration/actions/actions.class.php` | try/catch вокруг `send_mail_success()` (иначе 500 после создания юзера) |

### Flutter
| Файл | Изменение |
|------|-----------|
| `lib/services/api_client.dart` | `exchangePasswordForToken()`, `register()`, `masterGet/Set/Finish()` |
| `lib/services/auth_service.dart` | сохранение токена после нативного входа; `register()` + автологин |
| `lib/services/easy_api_credentials.dart` | **новый** — easyApi app_id/app_pass для регистрации |
| `lib/screens/auth/native_login_screen.dart` | **новый** — нативная форма |
| `lib/screens/auth/register_screen.dart` | **переписан** — нативная форма вместо WebView |
| `lib/screens/auth/login_screen.dart` | заменить WebView на нативный вход |
| `lib/screens/auth/oauth_webview_screen.dart` | fallback |
| `lib/screens/onboarding/**` | **новые** — шаги 1,2,3,5 |
| `lib/navigation/app_router.dart` | маршруты: логин, регистрация, онбординг, main |

---

## 9. Открытые вопросы

- Компания (`account_type=company`): цепочка `[1,5,6,7]`; finish не создаёт
  бюджет/цель и не трогает категории — проверить поведение на реальном company-аккаунте.

---

## 9.5 Нативная регистрация (✅ залито и проверено 21.09.2026)

**Проблема:** старый `RegisterScreen` — просто WebView на `easyfinance.ru/registration/`,
без автологина, спам категориями не управлял.

**Контракт (easyApi, не OAuth):**

| Пункт | Значение |
|-------|----------|
| Endpoint | `POST https://api.easyfinance.ru/registration.xml` |
| Параметры | `?app_id=<app>&app_pass=<pass>` (easyApi-креды, не OAuth) |
| Content-Type | `text/xml` |
| Тело (XML) | `<request><request_info><count_row>1</count_row><object>user</object></request_info><user><user_login>..</user_login><name>..</name><user_mail>..</user_mail><password>..</password></user></request>` |
| Ответ ok | `<results type="user"><user><id>UID</id><client_id></client_id><success>true</success><message>OK</message></user></results>` |
| Ответ ошибки | `<success>false</success><message>поле [поле [текст]]</message>` |
| Валидация | login уникальный + required, name required ≤100, e-mail формат+уникальный, password required ≤40 |

- `MyAuthFilter` для модуля `registration` пропускает без проверки юзера —
  достаточно пары `app_id`/`app_pass` (в старых клиентах было так же).
- После создания: `TariffSubscriptionTable::addTariffForNewUser`, письмо,
  `RegistrationModel::multipleInsertDefaultCategoriesAll`.

**Серверный фикс (важно):** `send_mail_success()` кидала исключение на SMTP
(`Failed to authenticate ... notification@easyfinance.ru`) ПОСЛЕ создания юзера →
500 и не создавались дефолтные категории. Обёрнуто в try/catch + `error_log`,
`defaultCategories` выполняется всегда. Файл:
`apps/easyApi/modules/registration/actions/actions.class.php`
(бэкап `.bak.REGISTER`).

**Клиент (Flutter):**

- `lib/services/easy_api_credentials.dart` — **новый** файл: easyApi app_id/app_pass.
- `api_client.dart` — `register()`, `_parseRegisterResponse()`, `_xmlEscape()`.
- `auth_service.dart` — `register()` → создание + автологин password-grant.
- `register_screen.dart` — **переписан**: нативная форма (Имя, E-mail, Логин,
  Пароль x2), клиентская валидация, на ошибки сервера — локализованные
  `error_login_taken`/`error_email_taken`/generic; после успеха — `/main` + PIN setup.
- Локали: добавлены ключи `auth.*` (де/ит/тр догнал порталы `login_hint`/`password_hint`).

**Тест (продакшн, одноразовые аккаунты):**

- `apitest_21192` — до фикса: success=true, но 500 (письмо); вход password-grant работал.
- `apitest_24221` (uid 48163375) — после фикса: `success=true`, id=48163375,
  вход password-grant → 302 + `access_token`, дефолтные категории созданы.

---

## 9.6 Фаза 3 — Нативный мастер первого входа (Flutter)

**Сервер:**
- `actions.class.php` (easyApi registration) — добавлен `prepareMasterForNewUser($uid)`:
  после создания юзера ставит `user_settings.is_master_completed = false` (зеркало
  `/v2`-пути в `UserData.php`). Без этого мастер не показывается (дефолт схемы = 1).
- Файл: `apps/easyApi/modules/registration/actions/actions.class.php` (бэкап `.bak.MASTER`).
- E2E-проверка: `apitest_master_260921181959` (uid 48163377) → `master.get` вернул
  `is_master_completed: false`, `master_chain: [1,8,2,3,5,6,7]`.
- Файл `apps/api/lib/apiDataClasses/MasterData.php` (`get()`, бэкап `.bak.MASTERGET`) —
  фикс для аккаунтов, созданных **до** введения мастера: старые аккаунты имеют
  `user_settings.is_master_completed = 1` по дефолту при `account_type IS NULL`.
  Новый мастер обязан спрашивать тип аккаунта (step 8), поэтому завершённым считаем
  только `flag=1 И account_type != NULL`:
  ```php
  $flagCompleted = !empty($userSettings) && (bool) $userSettings->getIsMasterCompleted();
  $isMasterCompleted = $flagCompleted && !empty($user->getAccountType());
  ```
  Проверено живым API после деплоя и reload fpm:
  - `apitest_e2e_260922095231008` (uid 48163386, `account_type=man`, mc=1) →
    `is_master_completed: true`, chain `[1,2,3,5,6,7]` (без регрессии);
  - `apitest_fix_260922260265` (uid 48163387, `account_type=NULL`) →
    `is_master_completed: false`, chain `[1,8,2,3,5,6,7]`.
  В БД под этот сценарий подпадает 4661 аккаунт (mc=1 + тип не выбран).

**Контракт API (подтверждён живыми запросами):**

| Метод | Тип | Тело | Ответ |
|---|---|---|---|
| `master.get` | GET (sig) | — | `{"master":{"is_active":bool,"is_master_completed":bool,"master_chain":[int]}}` |
| `master.set` | POST (sig) | `{"request":{"request_data":{"currency_default":int,"currency_list":[int],"has_automobile":bool,"has_motocycle":bool,"has_children":bool,"has_animals":bool,"pays_utilities":bool,"pays_renting":bool}}}` | `{"master":{"result":"saved"}}` |
| `master.finish` | POST (sig) | `{"request":{"request_data":{"budgetTotalAmount":float,"utilitiesAmount":float,"rentingAmount":float,"targetAmount":float}}}` | `{"master":{"result":"completed"}}` или `already_completed` |

**Цепочки шагов (из БД `firstTimeEntranceMaster_settings`):**

| Профиль | master_chain (сервер) | Показываем в приложении |
|---|---|---|
| Физлицо (`account_type IS NULL` — не выбран) | `[1,8,2,3,5,6,7]` | `[1,2,3,5]` (фильтр `{1,2,3,5}`) |
| Физлицо (`account_type` задан) | `[1,2,3,5,6,7]` | `[1,2,3,5]` (фильтр `{1,2,3,5}`) |
| Компания (`account_type = 'company'`) | `[1,5,6,7]` | `[1,5]` (фильтр `{1,2,3,5}`) |

Шаг 8 (выбор профиля) — отфильтрован клиентом: в цепочке он всегда первый (следует из
`account_type IS NULL`), поэтому клиент задаёт тип аккаунта до остальных шагов. Шаг 4 (календарь) — неактивен на сервере.

**Клиент (Flutter):**

- `lib/models/master_status.dart` — **новый** файл: модель `MasterStatus` (isActive, isMasterCompleted, masterChain).
- `api_client.dart` — `getMaster()`, `setMaster(data)`, `finishMaster(data)`.
- `auth_service.dart` — `checkMasterStatus()` → вызывает `getMaster()` и возвращает `MasterStatus`.
- `lib/screens/onboarding/master_onboarding_screen.dart` — **новый** файл: пошаговый онбординг
  с PageView. Шаги: 1 (валюта), 2 (категории-тогглы), 3 (бюджет+цель), 5 («Как начать учёт»).
  В конце вызывает `master.set` + `master.finish` → `/main`.
- `app_router.dart` — роут `/onboarding`, принимает `MasterStatus` в аргументах.
- Guard после входа: `login_screen.dart` (_tryRestore), `native_login_screen.dart` (_submit),
  `register_screen.dart` (_submit) — после успешной авторизации вызывают `checkMasterStatus()`;
  если `isActive && !isMasterCompleted` → `/onboarding`, иначе → `/main`.
- Локали: 8 файлов (ru/en/es/fr/pt/de/it/tr), ключи `onboarding.*`.

---

## 10. Безопасность

- Пароль — только по HTTPS, не хранится после логина.
- Токен — в `FlutterSecureStorage` (Android Keystore / iOS Keychain).
- `app_id` + `secret` хардкодятся в приложении (как сейчас).
