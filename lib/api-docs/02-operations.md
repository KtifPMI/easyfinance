# Operations API

## operations.get — Получить операции

**HTTP:** GET
**Метод:** `operations.get`

### Параметры

| Параметр | Описание |
|----------|----------|
| `from` | Начальная дата выборки (ISO 8601) |
| `to` | Конечная дата выборки |
| `interval_field` | `date`, `created_at`, `updated_at`, `deleted_at` |
| `limit` | Срез: `начало,количество` |

### Пример запроса

```
GET https://api.easyfinance.ru/v2/?method=operations.get&app_id=...&access_token=...&from=2024-01-01&to=2024-06-01&interval_field=date&sig=...
```

### Пример ответа

```json
{
  "response": {
    "response_data": {
      "operations": [
        {
          "id": "1",
          "type": "0",
          "amount": "-5500.00",
          "currency_id": "1",
          "account_id": "1",
          "category_id": "1",
          "date": "2024-06-01",
          "time": "14:30:00",
          "comment": "Продукты",
          "tags": "семья,еда",
          "state": "0",
          "created_at": "2024-06-01 14:30:00",
          "updated_at": "2024-06-01 14:30:00"
        }
      ]
    }
  }
}
```

### Поля операции

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | string | ID операции |
| `type` | string | `0`=расход, `1`=доход, `2`=перевод |
| `amount` | string | Сумма (отрицательная для расходов) |
| `currency_id` | string | ID валюты |
| `account_id` | string | ID счёта |
| `category_id` | string | ID категории |
| `to_account_id` | string | ID счёта-получателя (для переводов) |
| `date` | string | Дата (`YYYY-MM-DD`) |
| `time` | string | Время (`HH:MM:SS`) |
| `comment` | string | Комментарий |
| `tags` | string | Теги через запятую |
| `state` | string | `0`=активна, `2`=удалена |
| `created_at` | datetime | Дата создания |
| `updated_at` | datetime | Дата изменения |

**Важно:** `amount` — строка, отрицательная для расходов. В приложении используется `abs()`.

---

## operations.post — Добавить операцию

**HTTP:** POST
**Метод:** `operations.post`

### Тело запроса

```json
{
  "request": {
    "request_info": { "method": "operations.post" },
    "request_data": {
      "operations": [
        {
          "type": "0",
          "amount": "1500.00",
          "account_id": "1",
          "category_id": "1",
          "date": "2024-06-01",
          "time": "14:30:00",
          "comment": "Обед"
        }
      ]
    }
  }
}
```

### Параметры запроса

| Параметр | Описание |
|----------|----------|
| `options` | `client` — вернуть созданную операцию с ID |

---

## operations.set — Редактировать операцию

**HTTP:** POST
**Метод:** `operations.set`

### Тело запроса

```json
{
  "request": {
    "request_info": { "method": "operations.set" },
    "request_data": {
      "operations": [
        {
          "id": "1",
          "comment": "Новый комментарий"
        }
      ]
    }
  }
}
```

### Параметры запроса

| Параметр | Описание |
|----------|----------|
| `options` | `client` |
| `operation_id` | ID операции |
