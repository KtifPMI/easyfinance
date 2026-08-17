# Tags API

## tags.get — Получить теги

**HTTP:** GET
**Метод:** `tags.get`

### Пример запроса

```
GET https://api.easyfinance.ru/v2/?method=tags.get&app_id=...&access_token=...&sig=...
```

### Пример ответа

```json
{
  "response": {
    "response_data": {
      "tags": [
        {
          "id": "1",
          "text": "Семья"
        },
        {
          "id": "2",
          "text": "Работа"
        }
      ]
    }
  }
}
```

### Поля тега

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | string | ID тега |
| `text` | string | Название тега |

**Примечание:** В ответе тег содержит поля `text` (название), `user_id`, `operation_id`, `created_at`/`updated_at`/`deleted_at`. При создании/обновлении (`tags.post`/`tags.set`) название передаётся в поле `text` (не `name`). В операциях теги передаются как строка через запятую в поле `tags`.
