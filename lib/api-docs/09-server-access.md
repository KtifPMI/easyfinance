# V2 API — Как устроен вход на сервере (справочник)

Зачем этот файл: чтобы не искать заново пути, конфиги и способы вызвать V2 API.
Обновлён по реальным данным с сервера `easyfinance-app-1`.

---

## 1. Схема маршрутизации (как запрос доходит до кода)

```
Клиент (Flutter)
  │  GET https://api.easyfinance.ru/v2/?method=...&app_id=...&access_token=...&sig=...
  ▼
nginx  /etc/nginx/sites-available/api.easyfinance.ru
  │  location ~ /v2   →  rewrite ^(.*)$ /v2/index.php last
  ▼
/var/www/easyfinance.ru/sf/web.api2/index.php
  │  application = 'api'
  ▼
/var/www/easyfinance.ru/sf/apps/api/          ← ПРИЛОЖЕНИЕ V2 (настоящее)
  ├── config/routing.yml                      ← только '/' , '/test-request', '/result'
  ├── config/restConfig/queries_config.yml    ← ОПИСАНИЕ ВСЕХ МЕТОДОВ и параметров
  ├── config/fieldsMapping/fields_mapping.yml ← маппинг полей API ↔ поля БД
  ├── modules/index/actions/actions.class.php ← диспетчер (apiResponseManager)
  └── modules/common/actions/actions.class.php (oauthRedirectUrl /result, ошибки)
```

**Важно:** это НЕ то же самое, что `/var/www/easyfinance.ru/sf/web.api/` (приложение
`easyApi` — старое XML API с `/accounts.xml`, `/currencies.xml` и т.п.). Пути не путать!

---

## 2. Точные пути на сервере (SSH: user3@easyfinance-app-1)

| Что | Путь |
|-----|------|
| nginx-конфиг для api | `/etc/nginx/sites-available/api.easyfinance.ru` |
| Точка входа V2 | `/var/www/easyfinance.ru/sf/web.api2/index.php` |
| Приложение V2 | `/var/www/easyfinance.ru/sf/apps/api/` |
| Методы/параметры | `/var/www/easyfinance.ru/sf/apps/api/config/restConfig/queries_config.yml` |
| Маппинг полей | `/var/www/easyfinance.ru/sf/apps/api/config/fieldsMapping/fields_mapping.yml` |
| Диспетчер | `/var/www/easyfinance.ru/sf/apps/api/modules/index/actions/actions.class.php` |
| Старое XML API (НЕ v2) | `/var/www/easyfinance.ru/sf/apps/easyApi/` (web.api/) |
| Сборочные конфиги | `apiConfiguration.class.php`, `converterConfig/`, `error/`, `restConfig/` |

---

## 3. Как правильно вызвать V2 API (правила запроса)

**Base URL:** `https://api.easyfinance.ru/v2/`

**Обязательные параметры:**
| Параметр | Тип | Описание |
|----------|-----|----------|
| `method` | string | `users.get`, `accounts.get`, ... (обязателен) |
| `app_id` | int | id приложения (обязателен) |
| `sig` | string | MD5-подпись (обязателен) |
| `access_token` | string | OAuth-токен (обязателен, кроме шагов получения токена) |

**Необязательные (общие):** `redirect_uri`, `format` (json/xml), `from`, `to`,
`interval_field` (updated_at,created_at,deleted_at,date; default: updated_at),
`limit` (`начало,количество`), `transact_key`, `mail`, `user_id`, `response_type`.

**Подпись sig:** `sig = md5(secret_key + params)`, где `params` — отсортированные
`key=value` пары в строгом порядке: `method`, `app_id`, `access_token`, затем остальные
(по алфавиту). Пример в `00-overview.md`.

**Пример отладки с сервера (с любого хоста):**
```bash
curl -s "https://api.easyfinance.ru/v2/?method=currencies.get&app_id=<APP_ID>&access_token=<TOKEN>&sig=<SIG>"
```

> Real app_id/secret_key лежат в `lib/config.dart` (не коммитить). Для OAuth-обмена
> используются platform app_id 1-5 (см. план нативного логина).

---

## 4. Список методов V2 (из queries_config.yml)

| Метод | Параметры |
|-------|-----------|
| `users.get` | fields: id,name,login,mail,account_type,currency_list,currency_default,service_mail,phone,tariff_duration,accounts,operations,categories,patterns,tags,budget; options: deleted,noresponse,all |
| `users.set` | fields: mail,phone; options: client |
| `users.post` | options: client (регистрация) |
| `accounts.get` | fields: id,name,type_id,state,description,currency_id,user_id,created_at,updated_at,deleted_at,init_balance,balance; options: deleted,noresponse,operations; account_list |
| `accounts.set` | options: deleted,noresponse,client; account_id (integer) |
| `accounts.post` | options: deleted,noresponse,client |
| `operations.get` | fields: id,user_id,account_id,category_id,amount,date,time,comment,accepted,tags,type,transfer_account_id,transfer_amount,...; options: deleted,noresponse,details,init_balance,balance,accepted; operation_list, account_list |
| `operations.set` | options: noresponse,client; operation_id |
| `operations.post` | options: noresponse,client |
| `categories.get` | fields: id,parent_id,system_id,user_id,name,type,is_hidden,custom,...; options: deleted,noresponse; categories_list |
| `categories.set` | options: noresponse,client; category_id |
| `categories.post` | options: noresponse,client |
| `operationPatterns.get/.set/.post` | patterns |
| `tags.get` | fields: id,user_id,text,operation_id |
| `tags.post` | options; text (required) |
| `tags.set` | tag_id (required); text |
| `budget.get` | fields: planned,spent |
| `budget.categoriesget` | fields: id,category_id,planned,spent,period,date_start |
| `budget.categoriespost` | options: noresponse,client |
| `budget.categoriesset` | options: noresponse,client |
| `currencies.get` | fields: id,name,symbol,rate; currency_list |
| `systemCategories.get` | fields: id,name,is_public,type; system_category_list |
| `targets.get` | fields: id,title,type,state,amount,amount_done,percent_done,forecast_done,currency_id,account_id,category_id,date_begin,date_end,comment,photo,url,visible,close,done |
| `targets.set` | options; target_id |
| `targets.post` | options |
| `calendar.get/.post/.set/.delete/.accept` | поля календаря повторяющихся операций |
| `dashboard.get` | нет |
| `error.post` | fields: url |

---

## 5. Маппинг полей пользователя (важно для мастера входа)

Из `fields_mapping.yml` (`users`):

| API поле | Поле БД |
|----------|---------|
| `id` | `id` |
| `name` | `name` |
| `login` | `login` |
| `mail` | `user_mail` |
| `account_type` | `account_type` |
| `currency_list` | `currency_list` |
| `currency_default` | `currency_id` |
| `service_mail` | `user_service_mail` |
| `phone` | `sms_phone` |
| `password` | `password` (только в post_fields) |

**Пост-поля (users.post):** id, name, login, mail, account_type, currency_list,
currency_default, service_mail, phone, password.

---

## 6. Валюты (реальные id с сервера, НЕ как в старых доках!)

`cur_id` из таблицы `currency` БД:

| id | код | | id | код | | id | код | | id | код |
|----|-----|-|----|-----|-|----|-----|-|----|-----|
| 1 | RUB | | 5 | AUD | | 11 | **CNY** | | 17 | SEK |
| 2 | USD | | 6 | BYR | | 12 | NOK | | 18 | CHF |
| 3 | EUR | | 7 | DKK | | 13 | XDR | | 19 | JPY |
| 4 | UAH | | 8 | ISK | | 14 | SGD | | 169 | PLN |
| | | | 9 | KZT | | 15 | TRY | | 186 | BYN |
| | | | 10 | CAD | | 16 | GBP | | | |

**Наследие:** в старых док-файлах (`00-overview.md`) таблица валют ошибочна
(GBP=4, CHF=5, CNY=6, PLN=11 и т.д.). Реальные id — из серверной БД, см. выше.
Flutter-карта уже исправлена: `lib/utils/currency_utils.dart` (v1.41.115+274).

---

## 7. Чек-лист «как добраться до V2» (коротко)

1. SSH на `user3@easyfinance-app-1`.
2. Изменить методы: `/var/www/easyfinance.ru/sf/apps/api/config/restConfig/queries_config.yml`.
3. Изменить поля: `/var/www/easyfinance.ru/sf/apps/api/config/fieldsMapping/fields_mapping.yml`.
4. PHP-логика: `/var/www/easyfinance.ru/sf/lib/api/` (apiResponseManager и т.п.).
5. Прогнать тест curl (см. п.3).