# Users API

## users.get — Получить информацию о пользователе

**HTTP:** GET
**Метод:** `users.get`

**Также используется для полной синхронизации:** если в `fields` перечислить типы данных, сервер вернёт их все одним запросом.

### Параметры

| Параметр | Описание |
|----------|----------|
| `fields` | Опционально. Через запятую: `accounts,operations,categories,tags,budget,events,goals` |

### Пример запроса (информация о пользователе)

```
GET https://api.easyfinance.ru/v2/?method=users.get&app_id=...&access_token=...&sig=...
```

### Пример ответа

```json
{
  "response": {
    "response_data": {
      "users": [
        {
          "id": "46732644",
          "name": "Алексей Иванов",
          "mail": "alex@example.com",
          "login": "alex_ivanov",
          "account_type": "individual",
          "tariff_duration": "2025-01-01 00:00:00",
          "default_currency": "1",
          "created_at": "2024-01-01 12:00:00"
        }
      ]
    }
  }
}
```

### Поля пользователя

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | string | ID пользователя (uid) |
| `name` | string | Имя |
| `mail` | string | Email |
| `login` | string | Логин |
| `account_type` | string | `individual`, `self_employed`, `entrepreneur` |
| `tariff_duration` | string|null | Дата окончания тарифа (null = free) |
| `default_currency` | string | ID валюты по умолчанию |
| `created_at` | datetime | Дата регистрации |

### Типы учётных записей

| `account_type` | Роль |
|----------------|------|
| `individual` | Физическое лицо |
| `self_employed` | Самозанятый |
| `entrepreneur` | ИП |

---

## users.post — Регистрация пользователя

**HTTP:** POST
**Метод:** `users.post`

### Тело запроса

```json
{
  "request": {
    "request_info": { "method": "users.post" },
    "request_data": {
      "users": [
        {
          "login": "newuser",
          "password": "securepass",
          "name": "Новый пользователь",
          "mail": "new@example.com"
        }
      ]
    }
  }
}
```

### Поля для регистрации

| Поле | Тип | Обязательное | Описание |
|------|-----|:---:|----------|
| `login` | string | да | Логин |
| `password` | string | да | Пароль |
| `name` | string | да | Имя |
| `mail` | string | да | Email |
