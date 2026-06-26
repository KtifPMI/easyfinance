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
          "name": "Семья"
        },
        {
          "id": "2",
          "name": "Работа"
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
| `name` | string | Название тега |

**Примечание:** Теги — простые объекты, не имеют `created_at`/`updated_at` и других служебных полей. В операциях теги передаются как строка через запятую в поле `tags`.
