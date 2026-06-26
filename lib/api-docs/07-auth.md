# OAuth Authentication

## Алгоритм получения access_token (7 шагов)

### Шаг 1 — Запрос request_token

**HTTP:** GET
**URL:** `https://api.easyfinance.ru/v2/`

**Параметры:**

| Параметр | Описание |
|----------|----------|
| `app_id` | Идентификатор приложения |
| `response_type` | `code` |
| `sig` | Подпись запроса |

**Подпись (sig) для шага 1:** `uid` НЕ участвует (uid ещё нет)

```
params = "app_id=...&response_type=code"
sig = md5(secret_key + params)
```

**Пример запроса:**
```
GET https://api.easyfinance.ru/v2/?app_id=...&response_type=code&sig=...
```

### Шаг 2 — Редирект на страницу подтверждения

API делает редирект (HTTP 301/302/307/308) на страницу:
```
https://easyfinance.ru/my/access-permission
```

Приложение должно перехватить этот редирект и открыть URL в браузере/WebView.

### Шаг 3 — Пользователь подтверждает доступ

Пользователь на странице подтверждения разрешает или запрещает доступ.

### Шаг 4 — Получение request_token

Если пользователь разрешил, API редиректит на:
```
https://api.easyfinance.ru/v2/result?code=d91df47db90104cd9856e0654ab76fae
```

Если отказал:
```
https://api.easyfinance.ru/v2/result?access_denied
```

### Шаг 5 — Обмен request_token на access_token

**HTTP:** GET
**URL:** `https://api.easyfinance.ru/v2/`

**Параметры:**

| Параметр | Описание |
|----------|----------|
| `app_id` | Идентификатор приложения |
| `code` | request_token из шага 4 |
| `grant_type` | `authorization_code` |
| `response_type` | `token` |
| `sig` | Подпись |

**Подпись (sig) для шага 5:** `uid` НЕ участвует

```
params = "app_id=...&code=...&grant_type=authorization_code&response_type=token"
sig = md5(secret_key + params)
```

**Пример запроса:**
```
GET https://api.easyfinance.ru/v2/?app_id=...&code=d91df47db90104cd9856e0654ab76fae&grant_type=authorization_code&response_type=token&sig=...
```

### Шаг 6 — Получение access_token

API делает редирект (301/302/307/308) на:
```
https://api.easyfinance.ru/v2/result?access_token=fd32accf7e8e716399a25fc3d5318d28&expires_in=3600
```

`access_token` может быть в query-параметрах или в fragment (`#access_token=...`).

`expires_in` — время жизни в миллисекундах, или `all_time`.

### Шаг 7 — Использование access_token

Токен передаётся в каждом запросе к API как параметр `access_token`.

**Важно:** Начиная с шага 7, `uid` (ID пользователя) участвует в подписи `sig`.

```
sig = md5(secret_key + uid + params)
```

## Реализация в коде

### `ApiClient.buildOAuthCodeUrl()` — генерация URL для шага 1
- Параметры: `app_id`, `response_type=code`, `sig`
- Sig без uid

### `ApiClient.exchangeCodeForToken(code)` — обмен кода на токен (шаги 5-6)
- Использует `dart:io HttpClient` с `followRedirects: false`
- Перехватывает редиректы, извлекает `access_token` из:
  1. Query-параметров URI
  2. Fragment URI (`#access_token=...`)
  3. Тела ответа (JSON: `response.response_data.access_token`)
  4. Регулярных выражений по тексту ответа
- Sig без uid

### `setAuth(accessToken, userId)` — сохранение токена
- Вызывается после успешного получения токена
- Дальнейшие sig считаются с uid

## Хранение токена

**SharedPreferences** (через `AuthService.saveCredentials()`):
- `easyfinance_access_token`
- `easyfinance_user_id`
- `easyfinance_app_id`
- `easyfinance_secret_key`

`tryRestoreSession()` — восстанавливает сессию при запуске.
`logout()` — очищает всё.

## Обработка ошибок OAuth

| Ситуация | Действие |
|----------|----------|
| `access_denied` | Пользователь отказал в доступе |
| `Invalid sig` (код 61) | Неправильный порядок параметров в sig |
| Таймаут | `ApiException('Token exchange timeout', 'TIMEOUT')` |
| Токен не найден | `ApiException('Token not found in response...', 'TOKEN_NOT_FOUND')` |
