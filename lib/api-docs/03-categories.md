# Categories API

## categories.get — Получить категории

**HTTP:** GET
**Метод:** `categories.get`

### Пример запроса

```
GET https://api.easyfinance.ru/v2/?method=categories.get&app_id=...&access_token=...&sig=...
```

### Пример ответа

```json
{
  "response": {
    "response_data": {
      "categories": [
        {
          "id": "1",
          "name": "Продукты",
          "type": "-1",
          "icon": "catimg1",
          "parent_id": null,
          "custom": "0",
          "created_at": "2024-01-01 12:00:00",
          "updated_at": "2024-06-01 12:00:00"
        },
        {
          "id": "2",
          "name": "Зарплата",
          "type": "1",
          "icon": "catimg9",
          "parent_id": null,
          "custom": "0",
          "created_at": "2024-01-01 12:00:00",
          "updated_at": "2024-06-01 12:00:00"
        }
      ]
    }
  }
}
```

### Поля категории

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | string | ID категории |
| `name` | string | Название |
| `type` | string | `-1`=расход, `1`=доход |
| `icon` | string | Иконка (`catimg1`-`catimg33`) |
| `parent_id` | string|null | ID родительской категории |
| `custom` | string | `0`=системная, `1`=пользовательская |
| `created_at` | datetime | Дата создания |
| `updated_at` | datetime | Дата изменения |

### Маппинг icon → название

| icon | Название | icon | Название |
|------|----------|------|----------|
| `catimg1` | food | `catimg2` | transport |
| `catimg3` | housing | `catimg4` | shopping |
| `catimg5` | health | `catimg6` | entertainment |
| `catimg7` | education | `catimg8` | travel |
| `catimg9` | salary | `catimg10` | freelance |
| `catimg11` | business | `catimg12` | gift |
| `catimg13` | car | `catimg14` | sports |
| `catimg15` | dining | `catimg16` | utilities |
| `catimg17` | internet | `catimg18` | clothing |
| `catimg19` | children | `catimg20` | pets |
| `catimg21` | taxes | `catimg22` | insurance |
| `catimg23` | invest | `catimg24` | rent |
| `catimg25` | other_income | `catimg26` | other_expense |
| `catimg27` | transport | `catimg28` | sports |
| `catimg29` | dining | `catimg30` | food |
| `catimg31` | shopping | `catimg32` | health |
| `catimg33` | entertainment | | |

---

## categories.post — Добавить категорию

**HTTP:** POST
**Метод:** `categories.post`

### Тело запроса

```json
{
  "request": {
    "request_info": { "method": "categories.post" },
    "request_data": {
      "categories": [
        {
          "name": "Моя категория",
          "type": "-1",
          "icon": "catimg1",
          "parent_id": null
        }
      ]
    }
  }
}
```

### Параметры запроса

| Параметр | Описание |
|----------|----------|
| `options` | `client` — вернуть созданную категорию с ID |

---

## categories.set — Редактировать категорию

**HTTP:** POST
**Метод:** `categories.set`

### Тело запроса

```json
{
  "request": {
    "request_info": { "method": "categories.set" },
    "request_data": {
      "categories": [
        {
          "id": "1",
          "name": "Новое название"
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
| `category_id` | ID категории |
