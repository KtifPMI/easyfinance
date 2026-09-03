# План: нативный вход без WebView

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

---

## Серверные правки

### Файл: `/var/www/easyfinance.ru/sf/lib/oauthServer/sfOAuth2Server.php`

#### Правка 1: Включить password grant

**Строки ~200-202** — метод `getSupportedGrantTypes()`:

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

**Зачем:** Сообщает OAuth2 серверу, что он теперь принимает `grant_type=password`. Константа `OAUTH2_GRANT_TYPE_USER_CREDENTIALS` уже определена в `OAuth2.php` как `"password"`.

**Влияние:** Старый WebView flow (`grant_type=authorization_code`) продолжает работать без изменений.

#### Правка 2: Исправить `getUserAuthParams()`

**Строки ~120-135** — метод `getUserAuthParams()`:

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

**Зачем:** Читает `username` и `password` из запроса, хеширует пароль через `sha1` (как делает `login.controller.php`), проверяет в базе через `UserTable::getUserByLoginAndPass()`.

**Важно:** `UserTable::getUserByLoginAndPass($login, $pass)` принимает пароль уже захешированный (SHA1). Хранение в базе: `sha1(plain_password)`.

---

## Серверная инфраструктура (для контекста)

### Точка входа API v2
- **Файл:** `/var/www/easyfinance.ru/sf/web.api/index.php`
- **Приложение:** `easyApi`
- **Конфигурация:** `/var/www/easyfinance.ru/sf/apps/easyApi/config/easyApiConfiguration.class.php`

### Auth фильтр (существующий, для справки)
- **Файл:** `/var/www/easyfinance.ru/sf/apps/easyApi/lib/filters/myAuthFilter.php`
- Принимает `app_id`, `app_pass`, `username`, `password`
- Используется для синхронизации (не для OAuth)
- **Не используется** в текущем OAuth flow

### App credentials (из `myAuthFilter.php` и конфигов)
| Платформа | code (app_id) | password (app_pass) |
|-----------|---------------|---------------------|
| iPhone | 1 | UnHt9j3j5kl6 |
| Android | 2 | kUyTg3n3n5nH |
| Samsung | 3 | mjUybNn76Ybn |
| Chrome | 4 | ljSD7Asd8Wd7 |
| WinPhone | 5 | byiF9f1Hfewl |

### Flutter app использует
- **app_id:** `7e65ca8e482d55ad7ad31476d7b33dc64a7d0f60` (из `config.dart`)
- **secretKey:** `e3df02801d7e7073a0d042f6a040aa043b9fc003` (из `config.dart`)
- Этот app_id — для OAuth flow. Для password grant нужно использовать platform-specific app_id (1-5).

### Генерация токена (из `OauthServerAccessToken`)
```php
// Токен:
md5(base64_encode(pack('N6', mt_rand(), mt_rand(), mt_rand(), mt_rand(), mt_rand(), uniqid())));

// Срок жизни:
date("U", strtotime("+50 years"));
```

### Модель пользователя
- **Таблица:** `User` (Doctrine)
- **Пароль:** `sha1(plain_password)`
- **Метод проверки:** `UserTable::getUserByLoginAndPass($login, $hashed_pass)`
- **Поля:** `id`, `login`, `pass`, `name`, `user_mail`, `currency_id`

### OAuth2 библиотека
- **Файл:** `/var/www/easyfinance.ru/sf/lib/oauthServer/oauth2Lib/OAuth2.php`
- Уже поддерживает `OAUTH2_GRANT_TYPE_USER_CREDENTIALS = "password"`
- `createAccessToken()` генерирует токен и сохраняет в `OauthServerAccessToken`
- `grantAccessToken()` — основной метод обмена

### Роутинг API v2
- **Файл:** `/var/www/easyfinance.ru/sf/apps/easyApi/config/routing.yml`
- Формат: `?method=<module>.<action>` или отдельные URL
- Примеры: `/accounts.json`, `/operations.json`, `/user.json`

---

## Тестирование сервера

### Команда для теста
```bash
curl -s "https://api.easyfinance.ru/v2/?grant_type=password&username=ВАШ_ЛОГИН&password=ВАШ_ПАРОЛЬ&app_id=1&app_pass=UnHt9j3j5kl6&response_type=token"
```

### Ожидаемый ответ (успех)
```json
{
  "access_token": "a1b2c3d4e5f6...",
  "expires_in": 1577664000,
  "token_type": "bearer"
}
```

### Ожидаемый ответ (ошибка)
```json
{
  "error": "invalid_grant",
  "error_description": "Invalid credentials"
}
```

---

## Flutter-сторона (после успешного теста сервера)

### 1. Новый экран: `lib/screens/auth/native_login_screen.dart`

Нативная форма с полями:
- Email (TextField, keyboardType: email)
- Password (TextField, obscureText: true)
- Кнопка "Войти"
- Ссылка "Нет аккаунта? Зарегистрироваться"

### 2. API вызов

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

### 3. Сохранение токена

```dart
// В AuthService (lib/services/auth_service.dart)
await _secure.write(key: 'easyfinance_access_token', value: accessToken);
await _secure.write(key: 'easyfinance_user_id', value: userId);
```

### 4. Навигация

- `LoginScreen` → заменить WebView на `NativeLoginScreen`
- После успешного логина → `/main`
- WebView экран (`OAuthWebViewScreen`) — оставить как fallback или удалить

### 5. Регистрация (отдельная задача)

- Сейчас: WebView на `easyfinance.ru/registration/`
- Можно: нативная форма + `POST /v2/?method=users.post` (существует в API, но не подключена)

---

## Файлы для изменений

### Сервер
| Файл | Изменение |
|------|-----------|
| `/var/www/easyfinance.ru/sf/lib/oauthServer/sfOAuth2Server.php` | Добавить password grant + исправить `getUserAuthParams()` |

### Flutter
| Файл | Изменение |
|------|-----------|
| `lib/screens/auth/native_login_screen.dart` | **Новый** — нативная форма логина |
| `lib/screens/auth/login_screen.dart` | Заменить кнопку OAuth на нативный логин |
| `lib/screens/auth/oauth_webview_screen.dart` | Оставить как fallback или удалить |
| `lib/services/auth_service.dart` | Добавить метод `loginWithPassword()` |
| `lib/services/api_client.dart` | Добавить метод `exchangePasswordForToken()` |
| `lib/navigation/app_router.dart` | Обновить маршруты |

---

## Безопасность

- Пароль передаётся по HTTPS (обязательно)
- Токен хранится в `FlutterSecureStorage` (Android Keystore / iOS Keychain)
- Пароль НЕ хранится в приложении после логина
- Токен живёт 50 лет (как и при OAuth flow)
- `app_id` + `app_pass` хардкодятся в приложении (как и сейчас)
