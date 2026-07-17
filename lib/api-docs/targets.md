# Targets (Цели / Financial Goals)

## targets.get — Получить список целей

**HTTP:** GET  
**Метод:** `targets.get`

### Пример запроса

```
GET https://api.easyfinance.ru/v2/?method=targets.get&app_id=...&access_token=...&sig=...
```

### Пример ответа

```json
{
  "response": {
    "response_data": {
      "targets": [
        {
          "id": "1",
          "title": "Новый ноутбук",
          "type": "0",
          "state": "0",
          "amount": "100000.00",
          "amount_done": "35000.00",
          "currency_id": "1",
          "account_id": "1",
          "category_id": null,
          "date_begin": "2026-01-01",
          "date_end": "2026-12-31",
          "comment": null,
          "photo": null,
          "url": null,
          "visible": "1",
          "close": "0",
          "done": "0"
        }
      ]
    }
  }
}
```

### Поля цели

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | string | Уникальный идентификатор |
| `title` | string | Название цели |
| `type` | string | Тип (0 — накопление) |
| `state` | string | Состояние (0 — активна) |
| `amount` | string | Целевая сумма |
| `amount_done` | string | Накопленная сумма |
| `currency_id` | string | ID валюты (1 — RUB) |
| `account_id` | string | ID счёта для накоплений |
| `category_id` | string\|null | ID категории (опционально) |
| `date_begin` | string | Дата начала (YYYY-MM-DD) |
| `date_end` | string | Дата завершения (YYYY-MM-DD) |
| `comment` | string\|null | Комментарий |
| `photo` | string\|null | Фото/изображение |
| `url` | string\|null | Ссылка |
| `visible` | string | Видимость (1 — видна, 0 — скрыта/удалена) |
| `close` | string | Закрыта (1 — да, 0 — нет) |
| `done` | string | Выполнена (1 — да, 0 — нет) |

**Важно:** `targets.get` возвращает **все** цели, включая `visible=0`. Клиент должен фильтровать самостоятельно.

---

## targets.post — Создать цель

**HTTP:** POST  
**Метод:** `targets.post`

### Параметры запроса

| Параметр | Тип | Описание |
|----------|-----|----------|
| `options` | string | `client` — вернуть созданный объект с ID |
| `transact_key` | string | Ключ идемпотентности |

### Тело запроса

```json
{
  "request": {
    "request_data": {
      "targets": [
        {
          "title": "Новый ноутбук",
          "amount": "100000.00",
          "amount_done": "0.00",
          "visible": "1",
          "currency_id": "1",
          "date_begin": "2026-01-01",
          "date_end": "2026-12-31",
          "account_id": "1"
        }
      ]
    }
  }
}
```

### Ответ

```json
{
  "response": {
    "response_data": {
      "success": true,
      "targets": [
        {
          "id": "1",
          "title": "Новый ноутбук",
          "amount": "100000.00",
          "amount_done": "0.00",
          "visible": "1",
          "currency_id": "1",
          "date_begin": "2026-01-01",
          "date_end": "2026-12-31",
          "account_id": "1"
        }
      ]
    }
  }
}
```

### Обязательные поля

| Поле | Обязательное | Примечание |
|------|-------------|-----------|
| `title` | Да | Название цели |
| `amount` | Да | Целевая сумма (строкой, с двумя знаками) |
| `amount_done` | Нет | Уже накоплено (по умолчанию `0.00`) |
| `visible` | Нет | По умолчанию `1` |
| `currency_id` | Нет | По умолчанию `1` (RUB) |
| `date_begin` | Нет | Если не указана — сервер проставит текущую дату |
| `date_end` | Нет | Дедлайн |
| `account_id` | Нет | Счёт для накоплений |

---

## targets.set — Обновить цель

**HTTP:** POST  
**Метод:** `targets.set`

### Параметры запроса

| Параметр | Тип | Описание |
|----------|-----|----------|
| `target_id` | string | **Обязательно.** ID цели |
| `transact_key` | string | Ключ идемпотентности |

### Тело запроса

```json
{
  "request": {
    "request_data": {
      "targets": [
        {
          "id": "1",
          "title": "Новый ноутбук",
          "amount": "120000.00",
          "amount_done": "35000.00",
          "visible": "1",
          "currency_id": "1",
          "date_begin": "2026-01-01",
          "date_end": "2026-12-31",
          "account_id": "1"
        }
      ]
    }
  }
}
```

**Важно:** ID цели передаётся **дважды**: в URL-параметре `target_id` и в теле внутри объекта `targets[].id`.

### Поля для обновления

Аналогичны `targets.post`. Для удаления (скрытия) достаточно отправить:

```json
{
  "request": {
    "request_data": {
      "targets": [
        {
          "id": "1",
          "visible": "0"
        }
      ]
    }
  }
}
```
