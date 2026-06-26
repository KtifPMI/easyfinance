# Budget API

## budget.get — Получить бюджет

**HTTP:** GET
**Метод:** `budget.get`

### Пример запроса

```
GET https://api.easyfinance.ru/v2/?method=budget.get&app_id=...&access_token=...&sig=...
```

### Пример ответа

```json
{
  "response": {
    "response_data": {
      "budget": {
        "planned": "50000.00",
        "spent": "32450.00",
        "date_start": "2024-06-01",
        "date_end": "2024-06-30"
      }
    }
  }
}
```

### Поля бюджета

| Поле | Тип | Описание |
|------|-----|----------|
| `planned` | string | Запланированная сумма на период |
| `spent` | string | Потраченная сумма за период |
| `date_start` | string | Начало периода (YYYY-MM-DD) |
| `date_end` | string | Конец периода (YYYY-MM-DD) |

**Важно:** API возвращает только общий planned/spent без разбивки по категориям. Детальный бюджет по категориям хранится только локально в приложении.
