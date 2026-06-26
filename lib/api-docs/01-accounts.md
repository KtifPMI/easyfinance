# Accounts API

## accounts.get — Получить счета

**HTTP:** GET
**Метод:** `accounts.get`

### Параметры

| Параметр | Описание |
|----------|----------|
| `fields` | Опционально. Список полей через запятую. Для баланса: `init_balance,balance` |

### Пример запроса

```
GET https://api.easyfinance.ru/v2/?method=accounts.get&app_id=...&access_token=...&fields=init_balance,balance&sig=...
```

### Пример ответа

```json
{
  "response": {
    "response_data": {
      "accounts": [
        {
          "id": "1",
          "name": "Наличные",
          "type_id": "1",
          "currency_id": "1",
          "balance": "12500.00",
          "init_balance": "0.00",
          "icon": "accountimage1",
          "state": "0",
          "created_at": "2024-01-01 12:00:00",
          "updated_at": "2024-06-01 12:00:00"
        }
      ]
    }
  }
}
```

### Поля счёта

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | string | ID счёта |
| `name` | string | Название |
| `type_id` | string | Тип счёта (1,2,5,8,15,16) |
| `currency_id` | string | ID валюты (1=RUB) |
| `balance` | string | Текущий баланс |
| `init_balance` | string | Начальный баланс |
| `icon` | string | Иконка (`accountimage1`-`accountimage8`) |
| `state` | string | 0 — активен, 2 — архивирован |
| `created_at` | datetime | Дата создания |
| `updated_at` | datetime | Дата изменения |

---

## accounts.post — Добавить счёт

**HTTP:** POST
**Метод:** `accounts.post`
**Body:** JSON с `request.request_data.accounts[]`

### Тело запроса

```json
{
  "request": {
    "request_info": { "method": "accounts.post" },
    "request_data": {
      "accounts": [
        {
          "name": "Новый счёт",
          "type_id": "2",
          "currency_id": "1",
          "balance": "0",
          "init_balance": "0",
          "icon": "accountimage1"
        }
      ]
    }
  }
}
```

### Параметры запроса (query)

| Параметр | Описание |
|----------|----------|
| `options` | `client` — если нужно вернуть созданный объект с присвоенным ID |

---

## accounts.set — Редактировать счёт

**HTTP:** POST
**Метод:** `accounts.set`
**Body:** JSON с `request.request_data.accounts[]`

### Тело запроса

```json
{
  "request": {
    "request_info": { "method": "accounts.set" },
    "request_data": {
      "accounts": [
        {
          "id": "1",
          "name": "Новое название",
          "icon": "accountimage3"
        }
      ]
    }
  }
}
```

### Параметры запроса (query)

| Параметр | Описание |
|----------|----------|
| `options` | `client` — вернуть объект с обновлёнными данными |
| `account_id` | ID счёта |

### Маппинг icon → цвет

| icon | Цвет hex |
|------|----------|
| `accountimage1` | `#4CAF50` |
| `accountimage2` | `#2196F3` |
| `accountimage3` | `#FF9800` |
| `accountimage4` | `#9C27B0` |
| `accountimage5` | `#F44336` |
| `accountimage6` | `#00BCD4` |
| `accountimage7` | `#795548` |
| `accountimage8` | `#607D8B` |
