# План: нативный вход без WebView + нативный мастер входа

## Текущий flow (проблемы)

1. Пользователь нажимает "Войти" → открывается WebView
2. WebView загружает `https://api.easyfinance.ru/v2/?app_id=...&response_type=code&sig=...`
3. Сервер рендерит страницу логина на `easyfinance.ru`
4. Юзер вводит данные → сервер редиректит на `*.easyfinance.ru/v2/result?access_token=...` или `?code=...`
5. App перехватывает редирект → достаёт токен

**Проблемы WebView:** выглядит как браузер, нет контроля над UI, нет refresh token, нет PKCE.

---

## Целевой flow

1. Нативный экран с полями Email + Password
2. POST на `https://api.easyfinance.ru/v2/?grant_type=password&username=...&password=...&app_id=...&app_pass=...&response_type=token`
3. Сервер возвращает `{"access_token":"...","expires_in":...,"token_type":"bearer"}`
4. App сохраняет токен в `FlutterSecureStorage`
5. Все последующие запросы идут с `access_token`
6. Если у пользователя `is_master_completed = false` — показать **нативный мастер входа** (валидация онбординга)

---

# ЧАСТЬ 1. АРХИТЕКТУРА V2 API (актуально, проверено с сервера)

## 1.1 Схема маршрутизации (как запрос доходит до кода)

```
Клиент (Flutter)
  │  GET https://api.easyfinance.ru/v2/?method=...&app_id=...&access_token=...&sig=...
  ▼
nginx  /etc/nginx/sites-available/api.easyfinance.ru
  │  location ~ /v2   →  rewrite ^(.*)$ /v2/index.php last
  ▼
/var/www/easyfinance.ru/sf/web.api2/index.php
  │  application = 'api'
  ▼
/var/www/easyfinance.ru/sf/apps/api/          ← ПРИЛОЖЕНИЕ V2 (настоящее)
  ├── config/routing.yml                      ← только '/' , '/test-request', '/result'
  ├── config/restConfig/queries_config.yml    ← ОПИСАНИЕ ВСЕХ МЕТОДОВ и параметров
  ├── config/fieldsMapping/fields_mapping.yml ← маппинг полей API ↔ поля БД
  ├── modules/index/actions/actions.class.php ← диспетчер (apiResponseManager)
  └── modules/common/actions/actions.class.php (oauthRedirectUrl /result, ошибки)
```

**Важно:** `/var/www/easyfinance.ru/sf/web.api/` (приложение `easyApi`) — это СТАРОЕ XML API
с `/accounts.xml`, `/currencies.xml` и т.п. **НЕ путать с V2.** V2 — это только `api` (web.api2).

## 1.2 Точные пути на сервере (SSH: user3@easyfinance-app-1)

| Что | Путь |
|-----|------|
| nginx-конфиг для api | `/etc/nginx/sites-available/api.easyfinance.ru` |
| Точка входа V2 | `/var/www/easyfinance.ru/sf/web.api2/index.php` |
| Приложение V2 | `/var/www/easyfinance.ru/sf/apps/api/` |
| Методы/параметры | `/var/www/easyfinance.ru/sf/apps/api/config/restConfig/queries_config.yml` |
| Маппинг полей | `/var/www/easyfinance.ru/sf/apps/api/config/fieldsMapping/fields_mapping.yml` |
| Диспетчер | `/var/www/easyfinance.ru/sf/apps/api/modules/index/actions/actions.class.php` |
| Data-классы | `/var/www/easyfinance.ru/sf/apps/api/lib/apiDataClasses/` (UserData, AccountData, CategoryData...) |
| Валидаторы форм | `/var/www/easyfinance.ru/sf/apps/api/lib/form/apiValidatorForm/` (ApiUserMethod{Get,Post,Set}Form) |
| Формы синхронизации | `/var/www/easyfinance.ru/sf/apps/api/lib/form/apiDataSyncForm/User/` (syncUserSetForm, syncUserPostForm) |
| Core-хендлер | `/var/www/easyfinance.ru/sf/apps/api/lib/apiResponseManager.class.php` |
| Настройки приложений | `/var/www/easyfinance.ru/sf/lib/model/doctrine/ApiAppSettings.class.php` + `/var/www/easyfinance.ru/sf/lib/apiLib/appSettings/appSettingsManager.php` |
| Старое XML API (НЕ v2) | `/var/www/easyfinance.ru/sf/apps/easyApi/` (web.api/) |

## 1.3 Как правильно вызвать V2 API (правила запроса)

**Base URL:** `https://api.easyfinance.ru/v2/`

**Обязательные параметры:**
| Параметр | Тип | Описание |
|----------|-----|----------|
| `method` | string | `users.get`, `accounts.get`, ... (обязателен) |
| `app_id` | int | id приложения (обязателен) |
| `sig` | string | MD5-подпись (обязателен) |
| `access_token` | string | OAuth-токен (обязателен, кроме шагов получения токена) |

**Необязательные (общие):** `redirect_uri`, `format` (json/xml), `from`, `to`,
`interval_field` (updated_at,created_at,deleted_at,date; default: updated_at),
`limit` (`начало,количество`), `transact_key`, `mail`, `user_id`, `response_type`.

**Подпись sig:** `sig = md5(secret_key + params)`, где `params` — отсортированные
`key=value` пары в строгом порядке: `method`, `app_id`, `access_token`, затем остальные
(по алфавиту). Пример в `lib/api-docs/00-overview.md`.

**Пример отладки:**
```bash
curl -s "https://api.easyfinance.ru/v2/?method=currencies.get&app_id=<APP_ID>&access_token=<TOKEN>&sig=<SIG>"
```

## 1.4 Все методы V2 (из queries_config.yml)

| Метод | Параметры |
|-------|-----------|
| `users.get` | fields: id,name,login,mail,account_type,currency_list,currency_default,service_mail,phone,tariff_duration,accounts,operations,categories,patterns,tags,budget; options: deleted,noresponse,all |
| `users.set` | fields: mail,phone; options: client |
| `users.post` | options: client (регистрация) |
| `accounts.get/.set/.post` | счета |
| `operations.get/.set/.post` | операции |
| `categories.get/.set/.post` | категории |
| `operationPatterns.get/.set/.post` | шаблоны операций |
| `tags.get/.post/.set` | теги |
| `budget.get` | fields: planned,spent |
| `budget.categoriesget/.post/.set` | бюджет по категориям |
| `currencies.get` | fields: id,name,symbol,rate |
| `systemCategories.get` | fields: id,name,is_public,type |
| `targets.get/.set/.post` | финансовые цели |
| `calendar.get/.post/.set/.delete/.accept` | календарь (повторяющиеся операции) |
| `dashboard.get` | нет |
| `error.post` | fields: url |

## 1.5 Маппинг полей пользователя (fields_mapping.yml → users)

| API поле | Поле БД |
|----------|---------|
| `id` | `id` |
| `name` | `name` |
| `login` | `login` |
| `mail` | `user_mail` |
| `account_type` | `account_type` |
| `currency_list` | `currency_list` |
| `currency_default` | `currency_id` |
| `service_mail` | `user_service_mail` |
| `phone` | `sms_phone` |
| `password` | `password` (только в post_fields) |

**Пост-поля (users.post):** id, name, login, mail, account_type, currency_list,
currency_default, service_mail, phone, password.

## 1.6 Валюты (реальные id с сервера, НЕ как в старых доках!)

`cur_id` из таблицы `currency` БД (см. `lib/api-docs/09-server-access.md`):

| id | код | | id | код | | id | код | | id | код |
|----|-----|-|----|-----|-|----|-----|-|----|-----|
| 1 | RUB | | 5 | AUD | | 11 | **CNY** | | 17 | SEK |
| 2 | USD | | 6 | BYR | | 12 | NOK | | 18 | CHF |
| 3 | EUR | | 7 | DKK | | 13 | XDR | | 19 | JPY |
| 4 | UAH | | 8 | ISK | | 14 | SGD | | 169 | PLN |
| | | | 9 | KZT | | 15 | TRY | | 186 | BYN |
| | | | 10 | CAD | | 16 | GBP | | | |

**Наследие:** старые доки (00-overview.md) ошибочны (GBP=4, CHF=5, CNY=6, PLN=11).
Flutter-карта исправлена: `lib/utils/currency_utils.dart` (v1.41.115+274).

## 1.7 App credentials

Платформенные (из `myAuthFilter.php` и конфигов):
| Платформа | code (app_id) | password (app_pass) |
|-----------|---------------|---------------------|
| iPhone | 1 | UnHt9j3j5kl6 |
| Android | 2 | kUyTg3n3n5nH |
| Samsung | 3 | mjUybNn76Ybn |
| Chrome | 4 | ljSD7Asd8Wd7 |
| WinPhone | 5 | byiF9f1Hfewl |

Flutter app (для OAuth-подписи):
- **app_id:** `7e65ca8e482d55ad7ad31476d7b33dc64a7d0f60` (из `config.dart`)
- **secretKey:** `e3df02801d7e7073a0d042f6a040aa043b9fc003` (из `config.dart`)

Для password-grant login — использовать platform-specific app_id (1-5) + app_pass.

## 1.8 Настройки приложений (ApiAppSettings) — важные для нас константы

| Константа | keyword в БД | Назначение |
|-----------|--------------|-----------|
| `DISABLE_FEM` | `disable_fem` | Флаг «не показывать мастер первого входа». При регистрации через users.post: если включён → `is_master_completed=true`, иначе `false` |
| `CURRENCY_ISO` | `currency_iso` | Работа с валютами по ISO-кодам (конвертация currency_list в ISO в prepareResponse) |
| `USE_USERS_SET` | `use_users.set` | Право использовать метод users.set |
| `RETURN_ALL_USERS` | `return_all_users` | Возвращать всех юзеров приложения (опция `all`) |
| `GET_USER_BY_ID` / `GET_USER_BY_EMAIL` | ... | Получение юзера по id/email |
| `IS_BANKIRU` | `is_bankiru` | Флаг-определитель banki.ru (влияет на шаг 4 мастера) |
| `HIDE_CALENDAR_SETTINGS_IN_FIRST_TIME_ENTRANCE_MASTER` | ... | Скрывать шаг календаря в мастере |
| `GENERATE_ACCESS_TOKEN` | `generate_access_token` | Сгенерировать access_token при регистрации |
| `ABSOLUTE_TARIFF` | `absolute_tariff` | Абсолютный тариф при регистрации |
| `ADD_SPECIAL_CURRENCY_LIST` | `add_special_currency_list` | Спец. список валют (RUB, USD, EUR) |

Найти настройки: `AppSettingsManager::getSettingForApp($app_id, $keyword)` (таблица `api_app_settings`).

---

# ЧАСТЬ 2. ПРАВКИ ДЛЯ НАТИВНОГО ЛОГИНА (password grant)

## 2.1 Файл: `/var/www/easyfinance.ru/sf/lib/oauthServer/sfOAuth2Server.php`

### Правка 1: Включить password grant

**Метод `getSupportedGrantTypes()` (~строки 200-202):**

```php
// Было:
protected function getSupportedGrantTypes() {
    return array(OAUTH2_GRANT_TYPE_AUTH_CODE);
}

// Стало:
protected function getSupportedGrantTypes() {
    return array(
        OAUTH2_GRANT_TYPE_AUTH_CODE,
        OAUTH2_GRANT_TYPE_USER_CREDENTIALS
    );
}
```

**Влияние:** старый WebView flow (`authorization_code`) продолжает работать.

### Правка 2: Исправить `getUserAuthParams()` (~строки 120-135):

```php
// Было (сломано — $login/$pass не определены):
protected function getUserAuthParams() {
    if (!isset($_GET[OAUTH2_USER_AUTH_LOGIN_NAME]) || !isset($_GET[OAUTH2_USER_AUTH_PASS_NAME]))
        $this->errorResponse(OAUTH2_HTTP_BAD_REQUEST, OAUTH2_ERROR_INVALID_USER_AUTH, 'Invalid user authorization parameters');

    $user = UserTable::getUserByLoginAndPass(rtrim(ltrim($login)), rtrim(ltrim($pass)));

    if (empty($user))
        $this->errorResponse(OAUTH2_HTTP_BAD_REQUEST, OAUTH2_ERROR_INVALID_REQUEST, 'Auth header found that doesn\'t start with "OAuth"');

    return $user['id'];
}

// Стало:
protected function getUserAuthParams() {
    $login = $this->context->getRequest()->getParameter('username');
    $pass  = $this->context->getRequest()->getParameter('password');

    if (empty($login) || empty($pass))
        $this->errorResponse(OAUTH2_HTTP_BAD_REQUEST, OAUTH2_ERROR_INVALID_USER_AUTH, 'Missing username or password');

    $user = UserTable::getUserByLoginAndPass($login, sha1($pass));

    if (empty($user))
        $this->errorResponse(OAUTH2_HTTP_BAD_REQUEST, OAUTH2_ERROR_INVALID_REQUEST, 'Invalid credentials');

    return $user['0']['id'];
}
```

**Важно:** `UserTable::getUserByLoginAndPass($login, $pass)` принимает пароль уже
захешированный (SHA1). В базе пароль хранится как `sha1(plain_password)`.

## 2.2 Тестирование сервера

```bash
curl -s "https://api.easyfinance.ru/v2/?grant_type=password&username=ЛОГИН&password=ПАРОЛЬ&app_id=1&app_pass=UnHt9j3j5kl6&response_type=token"
```

**Успех:** `{"access_token":"...","expires_in":... ,"token_type":"bearer"}`
**Ошибка:** `{"error":"invalid_grant","error_description":"Invalid credentials"}`

---

# ЧАСТЬ 3. ПРАВКИ ДЛЯ НАТИВНОГО МАСТЕРА ВХОДА (V2 API)

## 3.1 Что уже умеет V2 API (шаги мастера ↔ методы)

| Шаг мастера | Есть в V2 | Комментарий |
|---|---|---|
| 1. Валюта | `currencies.get` (список) | Нет записи `currency_default`/`currency_list` через users.set |
| 2. Категории | `categories.get` + `systemCategories.get` | Запись через categories.post/set (is_hidden) |
| 3. Бюджет + цель | `budget.categoriespost` + `targets.post` | Есть |
| 4. Напоминания/календарь | `calendar.*`, users.set phone | Настройки календаря — нет отдельного метода |
| 5. Операция (пример) | `operations.post` | Заглушка даже в web-мастере |
| 6. Мобильное приложение | — | Нет поля mobile_application_id в users.set |
| 7. Загрузка из банка | — | web-мастер не сохраняет (отдельный flow) |
| 8. Профиль (тип) | — | Нет поля account_type в syncUserSetForm |
| 9. Бизнес-категории | categories.post | Заглушка в web-мастере |
| Finish | — | Нет завершения (is_master_completed + создание бюджета/цели) |

## 3.2 Ключевые находки в коде

**`is_master_completed` — поле есть в БД (`user_settings`), но НЕ в API.**
- При регистрации через `users.post` ставится автоматически:
  - если у приложения `disable_fem` → `true`
  - иначе → `false`
- Клиент НЕ может узнать флаг через `users.get` (нет поля в queries_config).
- Клиент НЕ может снять/установить флаг (нет в users.set).

**`syncUserSetForm` (users.set) умеет ТОЛЬКО:** `name`, `user_mail`, `sms_phone`.
Не умеет: `currency_list`, `currency_default`, `account_type`, `mobile_application_id`, `is_master_completed`.

**`syncUserPostForm` (users.post, регистрация):** login, name, user_mail, password,
sms_phone (+user_created/user_new/user_active автозаполнение). После создания:
- `RegistrationModel::multipleInsertDefaultCategoriesAll()` — дефолтные категории
- `RegistrationModel::addDefaultAccount()` — дефолтный счёт
- `UserSettings::setIsMasterCompleted()` (по disable_fem)
- тариф (absolute/special), extra mail и т.д.

**Web-мастер (firstTimeEntranceMaster) — эталон шагов и логики:**
`/var/www/easyfinance.ru/sf/apps/frontend/modules/firstTimeEntranceMaster/actions/actions.class.php`
- Step1: `currency_default` + `currency_list` (с учётом уже использованных валют)
- Step2: системные категории (has_automobile, has_motocycle, has_children, has_animals, pays_utilities, pays_renting)
- Step3: бюджет (budgetTotalAmount, utilitiesAmount, rentingAmount, budget_start_day) + цель (targetAmount) → **копятся в сессии**, применяются в Finish
- Step4: reminder-настройки (smsEnabled, smsPhone, gCalendar) → через profileActions::saveReminders
- Step6: mobile_application_id → UserSettings
- Step8: account_type (gender) → User
- Step9 (заглушка), Step5 (заглушка), Step7 (загрузка из банка — отдельно)
- Finish: `RegistrationModel::setDefaultCategoriesByUserProfileType($user)`
         + `RegistrationModel::showHideCategoriesByMasterSettings($user)`
         + `addFirstBudgetAndTarget()` — создание бюджета (проценты по дефолтным категориям) и фин. цели «Финансовая подушка» (Target::CATEGORY_ID_FINANCE_PILLOW)

## 3.3 Необходимые доработки сервера

### 3.3.1 `users.get` → добавить флаг мастер пройден

**Файл:** `/var/www/easyfinance.ru/sf/apps/api/config/restConfig/queries_config.yml`
- в `users.get.fields.value` добавить, например, `master_completed`

**Файл:** `/var/www/easyfinance.ru/sf/apps/api/config/fieldsMapping/fields_mapping.yml`
- в `users.fields` добавить `master_completed: is_master_completed` (поле в user_settings)

**Либо: отдельные методы** `master.get` / `master.set` — новый object в queries_config + свой ApiData-класс. **Рекомендуется.**

### 3.3.2 `users.set` → расширить поля

**Файл:** `/var/www/easyfinance.ru/sf/apps/api/lib/form/apiDataSyncForm/User/syncUserSetForm.class.php`
- добавить поля: `currency_id`, `currency_list`, `account_type`, `mobile_application_id`, `sms_phone` (уже есть)

**Но осторожно:** `users.set` использует `checkAndUpdateNewRecord` → `mappingContentData` —
учесть в `mappingContentData` новые поля и в `fields_mapping.yml` (post_fields).

### 3.3.3 Создание бюджета + цели + категорий по типу профиля

**Новый метод** (например `master.finish`) в V2 API, который повторит логику web:
- `RegistrationModel::setDefaultCategoriesByUserProfileType($user)`
- `RegistrationModel::showHideCategoriesByMasterSettings($user)` (по настройкам шага 2)
- `BudgetManager::getBudgetStartDate()` + `budgetActions::executeAdd`-логика (проценты DefaultCategoryBudgetProcentTable)
- создание `Target` типа "Финансовая подушка" (`Target::TYPE_SAVE_MONEY`, `CATEGORY_ID_FINANCE_PILLOW`, +30 месяцев)
- `UserSettings::setIsMasterCompleted(true)`

**Либо** минимум: клиент сам создаёт бюджет через `budget.categoriespost` и цель через `targets.post`,
а сервер только ставит флаг. Но тогда теряется «магия» дефолтного бюджета по процентам.

### 3.3.4 Регистрация (users.post) — уже готова
- Нативная регистрация = `users.post` (login, name, user_mail, password).
- Учесть: для партнёрских приложений может быть отключён `use_users.set`.

---

# ЧАСТЬ 4. FLUTTER-СТОРОНА

## 4.1 Нативный логин

### Файл: `lib/screens/auth/native_login_screen.dart`
Нативная форма: Email (TextField), Password (TextField obscure), кнопка "Войти",
ссылка "Нет аккаунта? Зарегистрироваться".

### API вызов
```dart
Future<String?> loginWithPassword(String email, String password) async {
  final uri = Uri.parse('https://api.easyfinance.ru/v2/').replace(queryParameters: {
    'grant_type': 'password',
    'username': email,
    'password': password,
    'app_id': '1',        // или platform-specific
    'app_pass': 'UnHt9j3j5kl6',
    'response_type': 'token',
  });

  final response = await http.get(uri);
  final data = jsonDecode(response.body);

  if (data['access_token'] != null) {
    return data['access_token'];
  }
  return null;
}
```

### Сохранение токена (AuthService, `lib/services/auth_service.dart`)
```dart
await _secure.write(key: 'easyfinance_access_token', value: accessToken);
await _secure.write(key: 'easyfinance_user_id', value: userId);
```

### Навигация
- `LoginScreen` → заменить WebView на `NativeLoginScreen`
- WebView-экран (`OAuthWebViewScreen`) — оставить как fallback или удалить

## 4.2 Нативный мастер входа

**Файлы (новые):**
- `lib/screens/onboarding/onboarding_screen.dart` — PageView по шагам мастера
- `lib/screens/onboarding/steps/step_currency.dart` — основная валюта + доп. валюты (есть `currencies.get`)
- `lib/screens/onboarding/steps/step_categories.dart` — системные категории (есть `systemCategories.get`)
- `lib/screens/onboarding/steps/step_budget.dart` — бюджет + цель
- `lib/screens/onboarding/steps/step_target.dart` — фин. цель (или объединить с бюджетом)
- `lib/screens/onboarding/steps/step_profile.dart` — тип профиля
- `lib/screens/onboarding/steps/step_mobile.dart` — моб. приложение

**Логика вызова после логина:**
```dart
// после получения токена
final user = await apiClient.getUser(); // users.get
if (user.masterCompleted != true) {
  Navigator.push(OnboardingScreen());   // нативный мастер
}
```

**Шаг 1 (валюта):** `users.set` с `currency_id` + `currency_list` (сериализованный список id)
— после расширения users.set. Пока нет — передать в `master.finish`.

**Шаг 3 (бюджет):** суммы копятся локально, применяются в финальном запросе `master.finish`
(или `budget.categoriespost` + `targets.post`).

**Финал:** вызов `master.finish` (или users.set со всеми полями) → после ответа идти в `/main`.

## 4.3 Регистрация (отдельная задача)

- Сейчас: WebView на `easyfinance.ru/registration/`
- Нативно: форма + `users.post` (login, name, user_mail, password)
- Сервер сам создаст дефолтные категории, счёт, флаг мастера

---

# ЧАСТЬ 5. ФАЙЛЫ ДЛЯ ИЗМЕНЕНИЙ

### Сервер
| Файл | Изменение |
|------|-----------|
| `/var/www/easyfinance.ru/sf/lib/oauthServer/sfOAuth2Server.php` | password grant + `getUserAuthParams()` |
| `/var/www/easyfinance.ru/sf/apps/api/config/restConfig/queries_config.yml` | поле `master_completed` в users.get; новый `master.finish` |
| `/var/www/easyfinance.ru/sf/apps/api/config/fieldsMapping/fields_mapping.yml` | `master_completed`, `mobile_application_id` |
| `/var/www/easyfinance.ru/sf/apps/api/lib/apiDataClasses/UserData.php` | вернуть флаг мастер; дописать поля в mappingContentData |
| `/var/www/easyfinance.ru/sf/apps/api/lib/form/apiDataSyncForm/User/syncUserSetForm.class.php` | currency_id, currency_list, account_type, mobile_application_id |
| `/var/www/easyfinance.ru/sf/apps/api/lib/apiDataClasses/MasterData.php` | **Новый** — выполнение логики finish-мастера |

### Flutter
| Файл | Изменение |
|------|-----------|
| `lib/screens/auth/native_login_screen.dart` | **Новый** — нативная форма логина |
| `lib/screens/auth/login_screen.dart` | Заменить кнопку OAuth на нативный логин |
| `lib/screens/auth/oauth_webview_screen.dart` | Fallback или удалить |
| `lib/services/auth_service.dart` | `loginWithPassword()` |
| `lib/services/api_client.dart` | `exchangePasswordForToken()`, `getUser()`, `finishMaster()` |
| `lib/screens/onboarding/**` | **Новые** — шаги мастера |
| `lib/navigation/app_router.dart` | Маршруты: логин, онбординг, main |

---

# ЧАСТЬ 6. БЕЗОПАСНОСТЬ

- Пароль передаётся по HTTPS (обязательно)
- Токен хранится в `FlutterSecureStorage` (Android Keystore / iOS Keychain)
- Пароль НЕ хранится в приложении после логина
- Токен живёт 50 лет (как и при OAuth flow)
- `app_id` + `app_pass` хардкодятся в приложении (как и сейчас)