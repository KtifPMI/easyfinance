# API EasyFinance.ru — Обзор

**Base URL:** `https://api.easyfinance.ru/v2/`
**Протокол:** HTTPS (порт 443)
**Формат данных:** JSON (по умолчанию)
**Даты:** ISO 8601 (`2011-09-21T18:55:30+04:00`)

---

## Параметры приложения

| Параметр | Значение |
|----------|----------|
| `app_id` | `7e65ca8e482d55ad7ad31476d7b33dc64a7d0f60` |
| `secret_key` | `e3df02801d7e7073a0d042f6a040aa043b9fc003` |

## Обязательные параметры каждого запроса

| Параметр | Тип | Описание |
|----------|-----|----------|
| `method` | string | Название метода API (например `accounts.get`) |
| `app_id` | string | Идентификатор приложения |
| `access_token` | string | OAuth-токен доступа (кроме шагов получения токена) |
| `sig` | string | Цифровая подпись запроса (MD5) |

## Необязательные параметры

| Параметр | Тип | Описание |
|----------|-----|----------|
| `from` | datetime | Начальная дата выборки |
| `to` | datetime | Конечная дата выборки |
| `interval_field` | string | Поле для временной выборки: `updated_at`, `created_at`, `deleted_at`, `date` |
| `limit` | string | Срез данных: `начало,количество` |
| `transact_key` | string | Ключ транзакции (для POST-запросов) |
| `fields` | string | Список полей через запятую |

## Формат ответа

```json
{
  "response": {
    "response_info": { "...": "..." },
    "response_data": {
      "accounts": [...],
      "operations": [...],
      "errors": [...]
    }
  }
}
```

## Ошибки

```json
{
  "response": {
    "response_error": {
      "error_code": "61",
      "error_message": "Invalid sig"
    }
  }
}
```

Или в `response_data.errors`:
```json
{
  "response_data": {
    "errors": [
      { "code": 61, "text": "Invalid sig" }
    ]
  }
}
```

## Подпись запроса (sig)

**Формула:** `sig = md5(secret_key + uid + params)`

- `uid` — ID пользователя (НЕ передаётся при OAuth-обмене, опционально для остальных)
- `params` — строка `key=value&key2=value2...`, где ключи отсортированы

**Порядок параметров для sig (строгий):**
1. `method`
2. `app_id`
3. `access_token`
4. Остальные в алфавитном порядке

**Пример:**
```
params = "method=accounts.get&app_id=423004&access_token=be6ef89965d58e56"
sig = md5("secret_key_here46732644method=accounts.get&app_id=423004&access_token=be6ef89965d58e56")
```

## Типы счетов

| `type_id` | Тип |
|-----------|------|
| 1 | Наличные (cash) |
| 2 | Дебетовая карта (debitCard) |
| 8 | Кредитная карта (creditCard) |
| 5 | Депозит (deposit) |
| 15 | Электронный (electronic) |
| 16 | Дебетовая карта (debitCard) |

## Типы операций

| `type` | Тип |
|--------|------|
| 0 | Расход (expense) |
| 1 | Доход (income) |
| 2 | Перевод (transfer) |

## Типы категорий

| `type` | Тип |
|--------|------|
| -1 | Расход (expense) |
| 1 | Доход (income) |

## Валюты

| ID | Код |
|----|-----|
| 1 | RUB |
| 2 | USD |
| 3 | EUR |
| 4 | GBP |
| 5 | CHF |
| 6 | CNY |
| 7 | JPY |
| 8 | BYN |
| 9 | UAH |
| 10 | KZT |
| 11 | PLN |
| 12 | CZK |
| 13 | SEK |
| 14 | NOK |

## Доступные методы

| Метод | Описание |
|-------|----------|
| `accounts.get` | Получить счета |
| `accounts.post` | Добавить счёт |
| `accounts.set` | Редактировать счёт |
| `operations.get` | Получить операции |
| `operations.post` | Добавить операцию |
| `operations.set` | Редактировать операцию |
| `categories.get` | Получить категории |
| `categories.post` | Добавить категорию |
| `categories.set` | Редактировать категорию |
| `tags.get` | Получить теги |
| `budget.get` | Получить бюджет |
| `users.get` | Получить информацию о пользователе |
| `users.post` | Регистрация пользователя |
