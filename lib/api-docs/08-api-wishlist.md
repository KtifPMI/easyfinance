# API Wishlist — что нужно добавить/изменить в API EasyFinance.ru

## 1. Регулярные платежи (recurring / scheduled operations)

**Проблема:** Нет CRUD для повторяющихся операций. Приходится хранить локально и вручную создавать операции.

**Нужные методы:**

### `scheduled.get` — Получить список регулярных платежей

**Параметры:** нет
**Ответ:**
```json
{
  "response": {
    "response_data": {
      "scheduled": [
        {
          "id": "1",
          "account_id": "1",
          "category_id": "1",
          "amount": "-5000.00",
          "type": "0",
          "comment": "Аренда",
          "tags": "жильё",
          "interval": "monthly",
          "interval_every": 1,
          "start_date": "2024-01-01",
          "end_date": null,
          "next_date": "2024-07-01",
          "created_at": "2024-01-01T12:00:00+03:00",
          "updated_at": "2024-06-01T12:00:00+03:00"
        }
      ]
    }
  }
}
```

**Поля:**
| Поле | Тип | Описание |
|------|-----|----------|
| `interval` | string | `daily`, `weekly`, `monthly`, `yearly`, `once` |
| `interval_every` | int | Каждые N дней/недель/месяцев |
| `start_date` | date | Дата первого платежа |
| `end_date` | date\|null | Дата окончания (null = бессрочно) |
| `next_date` | date | Следующая дата списания (вычисляется сервером) |

### `scheduled.post` — Добавить регулярный платёж

```json
{
  "request": {
    "request_data": {
      "scheduled": [
        {
          "account_id": "1",
          "category_id": "1",
          "amount": "-5000.00",
          "type": "0",
          "comment": "Аренда",
          "tags": "жильё",
          "interval": "monthly",
          "interval_every": 1,
          "start_date": "2024-01-01",
          "end_date": null
        }
      ]
    }
  }
}
```

### `scheduled.set` — Редактировать / удалить регулярный платёж

```json
{
  "request_data": {
    "scheduled": [
      {
        "id": "1",
        "amount": "-5500.00"
      }
    ]
  }
}
```
Удаление — через `deleted_at`.

---

## 2. Отчёты и аналитика

**Проблема:** Нет агрегирующего API. Чтобы построить график «расходы по категориям за месяц» надо выгрузить все операции и считать локально. На больших данных медленно.

### `reports.byCategory` — Суммы по категориям за период

**HTTP:** GET
**Параметры:**
| Параметр | Тип | Описание |
|----------|-----|----------|
| `from` | date | Начало периода |
| `to` | date | Конец периода |
| `type` | string | `expense`, `income`, `all` |
| `account_ids` | string | Опционально, фильтр по счетам |

**Ответ:**
```json
{
  "response": {
    "response_data": {
      "report": {
        "total": "-124500.00",
        "categories": [
          {
            "category_id": "1",
            "category_name": "Продукты",
            "total": "-45500.00",
            "count": 23,
            "icon": "catimg1"
          },
          {
            "category_id": "2",
            "category_name": "Транспорт",
            "total": "-12000.00",
            "count": 8,
            "icon": "catimg2"
          }
        ],
        "accounts": [
          {
            "account_id": "1",
            "account_name": "Наличные",
            "total": "-50000.00"
          }
        ],
        "by_date": {
          "2026-07-01": "-15000.00",
          "2026-07-02": "-8000.00"
        }
      }
    }
  }
}
```

### `reports.incomeExpense` — Доходы/расходы по месяцам

**Параметры:**
| Параметр | Тип | Описание |
|----------|-----|----------|
| `from` | date | Начало |
| `to` | date | Конец |
| `interval` | string | `month`, `week`, `day` |

**Ответ:**
```json
{
  "response": {
    "response_data": {
      "report": {
        "items": [
          {
            "period": "2026-07",
            "income": "150000.00",
            "expense": "-124500.00",
            "balance": "25500.00"
          }
        ]
      }
    }
  }
}
```

---

## 3. Финансовое здоровье (tachometers / dashboard)

**Проблема:** Есть на сайте (`/my/info/get-tachometers`), нет в v2 API. Использует отдельную авторизацию (PHPSESSID), недоступно для приложений.

### `dashboard.get` — Получить метрики финансового здоровья

**HTTP:** GET
**Параметры:** нет

**Ответ:**
```json
{
  "response": {
    "response_data": {
      "dashboard": [
        {
          "code": "overall",
          "title": "Итоговая оценка финансового здоровья",
          "value": 80,
          "max": 100,
          "description": "Хорошее финансовое состояние",
          "color": "#16A085"
        },
        {
          "code": "cash_reserve",
          "title": "Обеспеченность деньгами",
          "value": 100,
          "max": 100,
          "description": "Резерв на 6+ месяцев"
        },
        {
          "code": "budget_usage",
          "title": "Освоение бюджета",
          "value": 65,
          "max": 100,
          "description": "Бюджет на месяц"
        },
        {
          "code": "debt_burden",
          "title": "Долговая нагрузка",
          "value": 0,
          "max": 100,
          "description": "Доля доходов на кредиты"
        },
        {
          "code": "savings_rate",
          "title": "Накопления",
          "value": 17,
          "max": 100,
          "description": "Превышение доходов над расходами"
        }
      ]
    }
  }
}
```

---

## 4. Долги и кредиты

**Проблема:** Нет сущности «долг/кредит». Сейчас можно создать счёт с типом `credit`/`loan`, но нет графика платежей, процентов, остатка долга.

### `loans.get` — Получить список долгов/кредитов

### `loans.post` — Создать долг/кредит

### `loans.set` — Редактировать/погашать

```json
{
  "request_data": {
    "loans": [
      {
        "name": "Кредит в Сбере",
        "type": "credit",           // credit | debt | borrow
        "account_id": "5",          // счёт-источник платежей
        "total_amount": "500000.00",
        "remaining": "350000.00",
        "interest_rate": "15.5",
        "payment": "15000.00",      // ежемесячный платёж
        "start_date": "2024-01-15",
        "end_date": "2027-01-15",
        "creditor": "Сбербанк"
      }
    ]
  }
}
```

### `loans.get` — график платежей

**Параметры:**
| Параметр | Тип | Описание |
|----------|-----|----------|
| `id` | string | ID кредита |

**Ответ:**
```json
{
  "response_data": {
    "loan": {
      "...": "...",
      "schedule": [
        {
          "date": "2026-08-15",
          "payment": "15000.00",
          "principal": "12000.00",
          "interest": "3000.00",
          "remaining": "338000.00"
        }
      ]
    }
  }
}
```

---

## 5. Инвестиции

**Проблема:** Нет портфеля, ценных бумаг, доходности.

### `investments.get` — Портфель

### `investments.post` — Добавить сделку

```json
{
  "request_data": {
    "investments": [
      {
        "type": "stock",               // stock | bond | etf | crypto | deposit
        "ticker": "SBER",
        "name": "Сбербанк",
        "quantity": 100,
        "buy_price": "250.00",
        "current_price": "280.00",
        "currency_id": "1",
        "buy_date": "2025-01-10",
        "account_id": "3"              // счёт, с которого куплено
      }
    ]
  }
}
```

### `currencies.rates` — Курсы валют (актуальные)

**Нужен отдельный метод для получения текущих курсов, а не только список ID валют:**
```json
{
  "response_data": {
    "rates": [
      { "currency_id": "1", "code": "RUB", "rate": 1.0 },
      { "currency_id": "2", "code": "USD", "rate": 87.5 },
      { "currency_id": "3", "code": "EUR", "rate": 95.2 }
    ]
  }
}
```

---

## 6. Семейный доступ

**Проблема:** Нет возможности шарить данные между пользователями.

### `family.get` — Семья / участники

### `family.invite` — Пригласить участника

### `family.remove` — Удалить участника

---

## 7. Интеграция с банками

**Проблема:** Нет API для получения списка подключённых банков и статуса импорта.

### `bankConnections.get` — Список подключённых банков

### `bankConnections.sync` — Запросить синхронизацию

### `bankConnections.operations` — Получить новые операции из банка

---

## 8. Системные категории — `systemCategories.get`

**Уже существует в документации, но мы не пробовали.** Если заработает — использовать для создания пользовательских категорий.

---

## 9. `budget.post` / `budget.set` — по категориям

**Сейчас:** `budget.get` возвращает только общий planned/spent.
**Нужно:** Возможность задавать бюджет по категориям и получать детализацию:

```json
{
  "response_data": {
    "budgets": [
      {
        "category_id": "1",
        "category_name": "Продукты",
        "planned": "30000.00",
        "spent": "18500.00",
        "period": "month"
      }
    ]
  }
}
```

и соответствующие `budget.post` / `budget.set` с `category_id`.
