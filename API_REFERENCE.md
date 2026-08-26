# EasyFinance API Reference (v2)

Чистый, исчерпывающий справочник по API `api.easyfinance.ru/v2`, которым пользуется
мобильное приложение EasyFinance. Составлен по исходному коду приложения (не по
устаревшему PDF), поэтому здесь — ровно те методы и поля, которые реально
задействованы. Оригинальный (газлайтенный) документ — `EF_API.md` (там же §27 с
дополнениями по `calendar.*`, `targets.*`, `budget.categories*`, `tags.*`,
`categories.*`).

---

## 1. Общие сведения

- **Base URL:** `https://api.easyfinance.ru/v2/`
- **Формат данных:** JSON. Все ответы обёрнуты в `{"response": {...}}`.
- **Кодировка:** UTF-8. Поля дат — строки в формате
  `YYYY-MM-DDTHH:MM:SS+HH:MM` (например, `2026-08-26T15:04:05+03:00`).
- **Обязательные параметры каждого запроса:** `method`, `app_id`, `access_token`
  (не нужен только на этапе получения токена), `sig`.
- **Идемпотентность POST:** каждый POST содержит `transact_key` — уникальный ключ,
  сгенерированный клиентом (при повторе запроса с тем же `transact_key` сервер
  не создаёт дубль).

---

## 2. Аутентификация

Приложение использует **OAuth (authorization code flow)**. Альтернативный
login/password-флоу описан в оригинале (§12–§17) и тоже поддерживается сервером.

### 2.1 OAuth (используется приложением)

1. **Получение URL авторизации** — `buildOAuthCodeUrl()`:
   ```
   GET https://api.easyfinance.ru/v2/
       ?app_id=APP_ID
       &response_type=code
       &sig=SIG
   ```
   (без `method` и `access_token`; `sig` строится **без** `uid`).

   Открыть этот URL в браузере/WebView. Пользователь логинится на сайте и
   получает `code`.

2. **Обмен `code` на токен** — `exchangeCodeForToken(code)`:
   ```
   GET https://api.easyfinance.ru/v2/
       ?app_id=APP_ID
       &code=CODE
       &grant_type=authorization_code
       &response_type=token
       &sig=SIG
   ```
   (без `method`; `sig` строится **без** `uid`). Сервер отдаёт `access_token`
   и `uid` (в редиректе `location` или в теле ответа).

3. Далее во всех запросах передаются `access_token` и `uid` (для подписи `sig`).

### 2.2 Login / password (альтернатива)

- `POST` на сайт `https://easyfinance.ru/login/` с `login`, `pass` → cookie
  `PHPSESSID` (используется веб-эндпоинтами, см. §6).
- Для API v2 приложение также может получить `access_token` и `uid` по связке
  `app_id` + `secret_key` (см. оригинал §12–§17). `secret_key` и `app_id`
  выдаются разработчику при регистрации приложения.

---

## 3. Подпись запроса (`sig`)

`secret_key` — секрет приложения. Формула (конкатенация строк **без**
разделителей, не точка):

- До получения `uid` (обмен code→token, OAuth-шаги выше):
  `sig = md5(secret_key + params_string)`
- После получения `uid` (все остальные запросы):
  `sig = md5(secret_key + uid + params_string)`

Где `params_string` — строка всех параметров запроса (без самого `sig`),
значения которых URL-кодируются; порядок параметров важен только для расчёта
подписи. Пример расчёта — в оригинале (§17).

---

## 4. Формат вызова

### 4.1 GET
Параметры в query-строке: `method`, `app_id`, `access_token`, `<доп. параметры>`,
`sig`. Все они (включая доп.) входят в `params_string` для подписи.

```
GET https://api.easyfinance.ru/v2/
    ?method=accounts.get
    &app_id=APP_ID
    &access_token=TOKEN
    &fields=id,name
    &sig=SIG
```

### 4.2 POST
- Параметры в query: `method`, `app_id`, `access_token`, `transact_key`,
  `<id-параметры: operation_id / chain_id / category_id / tag_id / target_id /
  operation_pattern_id>` (все входят в подпись), `sig`.
- Тело запроса — JSON в `Content-Type: application/json`:
  ```json
  {
    "request": {
      "request_data": { "<объект или массив записей>" }
    }
  }
  ```
  Конкретные обёртки (`operations`, `categories`, `tags`, `targets`,
  `operationPatterns`, `calendar`, `budgets`) указаны в каждом методе.

### 4.3 Ответ
Успех:
```json
{ "response": { "response_data": { "accounts": [ ... ] } } }
```
Ошибка (вложенная):
```json
{ "response": { "response_error": { "error_code": "...", "error_message": "..." } } }
```
или список ошибок валидации:
```json
{ "response": { "response_data": { "errors": [ { "code": ..., "text": "..." } ] } } }
```

### 4.4 Общие параметры
- `fields` — список возвращаемых полей через запятую (по умолчанию — все).
- `options` — опции: `client` (вернуть `client_id`), `noresponse` (не возвращать
  тело ответа). Для POST передаётся в query.
- `transact_key` — обязателен для всех POST.
- `client_id` — идентификатор объекта в стороннем приложении (используется для
  сопоставления при создании операций/счетов/категорий).

---

## 5. Методы работы со счетами — `accounts.*`

### accounts.get
**GET.** Параметры: `account_list` (ids через запятую, опц.), `fields` (опц.).
**Ответ:** `response_data.accounts[]` — список счетов. Поля счета:

| Поле | Тип | Описание |
|---|---|---|
| `id` | int | Идентификатор счета |
| `name` / `title` | string | Название |
| `balance` | decimal | Текущий баланс |
| `currency_id` | int | ID валюты (1=RUB, 2=USD, 3=EUR, 4=GBP, 5=CHF, 6=CNY, 7=JPY, 8=BYN, 9=UAH, 10=KZT, 11=PLN, 12=CZK, 13=SEK, 14=NOK) |
| `currency_char_code` | string | Код валюты (RUB, USD, …) |
| `type_id` | int | Тип счета (см. маппинг ниже) |
| `state` | int | `1` — избранный, `2` — в архиве |
| `icon` | string | Код иконки `accountimageN` |
| `include_in_total` | 0/1 | Учитывать в общем балансе |
| `init_balance` | decimal | Начальный баланс |
| `created_at`, `updated_at` | datetime | Даты |
| `description` | string | Описание (кредиты) |
| `bank_id` | int | ID банка (кредиты) |
| `annual_rate` | decimal | Годовая ставка (кредиты) |
| `payment_type` | string | Тип платежа (кредиты) |
| `open_date`, `close_date` | date | Даты (кредиты) |
| `commission_one_time`, `commission_monthly` | decimal | Комиссии (кредиты) |
| `payment_day` | int | День платежа (кредиты) |
| `credit_limit` | decimal | Кредитный лимит (кредиты) |

**Маппинг `type_id` → тип:** `1` cash, `2` card, `5` deposit, `6` loan_given,
`7` loan_received, `8` credit_card, `9` credit, `10` oms, `11` stocks, `12` pif,
`13` ofbu, `14` pension, `15` electronic, `16` bank_account, `17` real_estate,
`18` car, `19` other_securities, `20` fund, `21` insurance_savings, `22` savings_plan,
`23` npf, `24` water_transport, `25` art, `26` business, `27` other_property,
`28` air_transport, `29` motorcycle, `30` bonds, `31` pamm, `32` broker, `33` bonus_card.
**Иконки:** `accountimage1` cash, `accountimage2` credit_card, `accountimage3` savings,
`accountimage4` account_balance, `accountimage5` wallet, `accountimage6` payments,
`accountimage7` currency_ruble, `accountimage8` card_giftcard.

### accounts.post
**POST.** Query: `transact_key` (и опц. `options=client`).
**Тело:** `{"request":{"request_data":{"accounts":[{ ... }]}}}`.
Поля записи: `name`, `init_balance` (строка, 2 знака), `type_id`, `state` (`"0"`),
`currency_id` (`"1"` если не задан), `icon` (`accountimageN`),
`include_in_total` (`"1"`/`"0"`), `created_at`, `updated_at`, а для кредитных —
необязательно: `description`, `bank_id`, `annual_rate`, `payment_type`,
`open_date`, `close_date`, `commission_one_time`, `commission_monthly`,
`payment_day`, `credit_limit`.
**Ответ:** `response_data.accounts[0].id` — новый ID счета.

### accounts.set
**POST.** Query: `transact_key`, `account_id`.
**Тело:** `{"request":{"request_data":{"accounts":[{ "id": "...", ...те же поля, что у post, + "updated_at" }]}}}`.
Используется для редактирования, для «избранного» (`state="1"`) и для
**архивации/удаления** (`state="2"`, сервер делает soft-delete). Отдельного
`accounts.delete` приложение не вызывает.

---

## 6. Операции — `operations.*`

### operations.get
**GET.** Параметры (опц.): `operation_list` (ids через запятую), `date_from`,
`date_to`, `limit`, `fields`, `interval_field` (`created_at`/`updated_at`/`deleted_at`/`date`).
**Ответ:** `response_data.operations[]`. Поля операции: `id`, `account_id`,
`amount` (положительное число; знак определяется `type`), `date`, `time`,
`category_id`, `comment`, `accepted` (`0`/`1`), `tags` (строка тегов через запятую
или JSON-массив), `type` (`0` расход, `1` доход, `2` перевод),
`transfer_account_id`, `transfer_amount`, `created_at`, `updated_at`,
`deleted_at`, `client_id`, `mcc_code`, `merchant_name`.

### operations.post
**POST.** Query: `transact_key`, `options=client`.
**Тело:** `{"request":{"request_data":{"operations":[{ ... }]}}}`.
Поля записи:
- `type` — `0`/`1`/`2`.
- `user_id` — id пользователя.
- `account_id` — счет списания.
- `category_id` — категория (для перевода — служебная категория «Перевод»).
- `currency_id` — валюта счета.
- `amount` — **знаковое** число: расход и перевод — отрицательное, доход —
  положительное (`income ? +amount : -amount`), формат с 2 знаками.
- `date` (`YYYY-MM-DDTHH:MM:SS+HH:MM`), `time` (`HH:MM:SS`).
- `transfer_account_id`, `transfer_amount` — для перевода (`transfer_amount`
  положительное).
- `comment`, `tags` (опц.).
- `accepted` — `true`.
- `client_id` — для сопоставления с серверным `id`.
- `created_at`, `updated_at`.
**Ответ:** `response_data.operations[0]` с `id` и `client_id`.

### operations.set
**POST.** Query: `transact_key`, `operation_id`.
**Тело:** `{"request":{"request_data":{"operations":[{ "id": "...", те же поля, что у post, + "updated_at", "deleted_at": null }]}}}`.
Для удаления операции передаётся `state="2"` (soft-delete) либо `deleted_at`.

---

## 7. Категории — `categories.*`

(См. также §27.6 в `EF_API.md`.)

### categories.get
**GET.** Параметры (опц.): `categories_list`, `fields`.
**Ответ:** `response_data.categories[]`. Поля: `id`, `system_id`, `name`,
`type` (`-1` расход, `1` доход), `custom` (`0` системная, `1` пользовательская),
`icon` (`catimgN`, catimg1..catimg33), `parent_id`, `is_hidden` (`0`/`1`),
`created_at`, `updated_at`, `deleted_at`, `client_id`.

### categories.post
**POST.** Query: `transact_key`.
**Тело:** `{"request":{"request_data":{"categories":[{ "name", "type":"-1"|"1", "icon":"catimgN", "system_id":"0", "custom":"1", "parent_id":"0", "is_hidden":"0", "created_at", "updated_at" }]}}}`.
**Ответ:** `response_data.categories[0].id`.

### categories.set
**POST.** Query: `transact_key`, `category_id`.
**Тело:** `{"request":{"request_data":{"categories":[{ "id", "name", "type", "icon":"catimgN", "system_id", "custom":"0"|"1", "parent_id", "is_hidden":"0", "created_at", "updated_at", "deleted_at" (для удаления) }]}}}`.
Удаление — через `deleted_at` (soft-delete); отдельного `categories.delete` нет.

---

## 8. Теги — `tags.*`

(См. также §27.5 в `EF_API.md`.)

### tags.get
**GET.** Параметры (опц.): `fields`, `tags_list`.
**Ответ:** `response_data.tags[]`. Поля тега: `id`, `user_id`, `text` (текст тега —
**поле называется `text`, не `name`**), `operation_id` (опц.).

### tags.post
**POST.** Query: `transact_key`.
**Тело:** `{"request":{"request_data":{"tags":[{ "name": "<текст>" }]}}}`.
Обратите внимание: при **записи** поле — `name`, при **чтении** сервер возвращает
`text`. **Ответ:** созданный тег с `id`.

### tags.set
**POST.** Query: `transact_key`, `tag_id`.
**Тело:** `{"request":{"request_data":{"tags":[{ "id", "name", "deleted_at":"<дата>" }]}}}`.
Используется для «мягкого» удаления тега (проставить `deleted_at`). Отдельного
`tags.delete` нет.

---

## 9. Цели (финансовые) — `targets.*`

(См. также §27.2 в `EF_API.md`.)

### targets.get
**GET.** **Ответ:** `response_data.targets[]`. Поля: `id`, `title`, `type` (`0`),
`state` (`0`), `amount` (цель, строкой), `amount_done` (накоплено, строкой),
`currency_id` (`1` RUB), `account_id`, `category_id`, `date_begin`, `date_end`,
`comment`, `photo`, `url`, `visible` (`1`/`0`), `close`, `done`.
Сервер возвращает ВСЕ цели, включая `visible=0`; клиент фильтрует скрытые сам.

### targets.post
**POST.** Query: `transact_key`, `options=client`.
**Тело:** `{"request":{"request_data":{"targets":[{ "title", "amount", "amount_done":"0.00", "end":"YYYY-MM-DD" (необяз.), "currency_id":"1", "date_begin", "date_end", "account_id", "category_id", "comment", "visible":"1" }]}}}`.
**Ответ:** созданная цель с `id`.

### targets.set
**POST.** Query: `transact_key`, `target_id`.
**Тело:** `{"request":{"request_data":{"targets":[{ "id": "<target_id>", ...поля цели }]}}}`.
Для скрытия/удаления достаточно `{"id": "<target_id>", "visible": "0"}`.

---

## 10. Бюджет — `budget.*`

### budget.get
**GET.** **Ответ:** `response_data.budget` (объект, не массив). Поля: `planned`
(плановая сумма на период), `spent` (фактически потрачено), `date_start`,
`date_end`.

### budget.categoriesget  (имя метода — слитно, без точки)
**GET.** **Ответ:** `response_data.budgets[]`. Поля: `id`, `category_id`
(к какой категории план), `planned` (план на период, строкой), `spent`
(фактически потрачено за период).

### budget.categoriespost
**POST.** Query: `transact_key`, `options=client`.
**Тело:** `{"request":{"request_data":{ "category_id": "<id>", "planned": "<сумма>" }}}`.

### budget.categoriesset
**POST.** Query: `transact_key`.
**Тело:** `{"request":{"request_data":{ "id": "<id плана>", "category_id": "<id>", "planned": "<сумма>" }}}`.

---

## 11. Календарь / Планировщик — `calendar.*`

(См. также §27.1 в `EF_API.md`.)

### calendar.get
**GET.** Параметры (опц.): `from`, `to`, `options` (`accepted` — только
подтверждённые вхождения). **Ответ:** `response_data.calendar[]`. Поля события:
`id`, `operation_id`, `chain_id`, `account_id`, `transfer_account_id`,
`category_id`, `amount`, `date`, `time`, `comment`, `type` (`0` расход, `1` доход,
`2` перевод), `accepted`, `every_day` (`1`/`7`/`30`/`90`/`365`), `repeat`
(`"1"` разовый, `"0"` до `date_end`, иначе — число вхождений), `date_start`,
`date_end`, `week_days` (маска 7 символов Пн..Вс), `tags`.

### calendar.post
**POST.** Query: `transact_key`.
**Тело:** `{"request":{"request_data":{ <объект события> }}}` (без массива). Поля:
`account_id`, `category_id`, `amount`, `date`, `time`, `comment`, `type`,
`transfer_account_id`, `transfer_amount`, `accepted`, `every_day`, `date_start`,
`date_end`, `repeat`, `week_days`. **Ответ:** созданное событие с `id` и `chain_id`.

### calendar.set
**POST.** Query: `transact_key`, `operation_id`, `chain_id`.
**Тело:** `{"request":{"request_data":{ <объект события> }}}`.

### calendar.delete
**POST.** Query: `transact_key`, `operation_id`, `chain_id`.
**Тело:** `{"request":{"request_data":{}}}`.

### calendar.accept
**POST.** Query: `transact_key`, `operation_id`, `chain_id`.
**Тело:** `{"request":{"request_data":{"date":"YYYY-MM-DD", "accepted":1}}}`.

---

## 12. Шаблоны операций — `operationPatterns.*`

### operationPatterns.get
**GET.** Параметры (опц.): `operation_pattern_list`, `fields`.
**Ответ:** `response_data.operationPatterns[]`. Поля: `id`, `type` (`0` расход,
`1` доход, `2` перевод, `3` начальный остаток, `4` перевод на цель), `account_id`,
`transfer_account_id`, `transfer_amount`, `category_id`, `user_id`, `amount`,
`name`, `icon` (`{ "code": "catimgN" }`), `comment`, `tags`, `created_at`,
`updated_at`, `deleted_at`, `client_id`.

### operationPatterns.post
**POST.** Query: `transact_key`, `options=client`.
**Тело:** `{"request":{"request_data":{"operationPatterns":[{ "client_id", "user_id", "name", "type" (int), "icon":{"code":"catimgN"}, "icons":...}, "amount", "account_id" (опц.), "category_id" (опц.), "transfer_account_id" (опц.), "comment" (опц.), "tags" (опц.), "created_at", "updated_at" }]}}}`.
**Ответ:** `response_data.operationPatterns[0].id`.

### operationPatterns.set
**POST.** Query: `transact_key`, `operation_pattern_id`.
**Тело:** `{"request":{"request_data":{"operationPatterns":[{ "id", "deleted_at":"<дата>" (для удаления) | полный рекорд для редактирования }]}}}`.
Удаление шаблона — через `deleted_at`.

---

## 13. Справочники — `currencies.*`, `systemCategories.*`, `users.*`

### currencies.get
**GET.** **Ответ:** `response_data.currencies[]`. Поля: `id`, `char_code`
(например, `RUB`), `currency_char_code`, `name`, `rate` (опц.), `symbol` (опц.).

### systemCategories.get
**GET.** **Ответ:** `response_data.systemCategories[]` — те же поля, что у
`categories.get` (встроенные системные категории, `custom=0`).

### users.get
**GET.** Параметры (опц.): `fields` (например, `goals`).
**Ответ:** поля на уровне `response_data`: `id`, `name`/`title`, `login`,
`mail`/`email`, `account_type`, `default_currency` (id валюты → код),
`tariff_duration` (дата окончания тарифа), `created_at`. При `fields=goals`
дополнительно `response_data.goals[]` — список целей пользователя.

---

## 14. Веб-эндпоинты (не по схеме `method=`, требуют cookie `PHPSESSID`)

Получается при веб-логине (`POST https://easyfinance.ru/login/` с `login`, `pass`
→ cookie `PHPSESSID`).

- **События календаря (сайт):** `GET https://easyfinance.ru/calendar/events/?responseMode=json`
- **Создание события календаря (сайт):** `POST https://easyfinance.ru/calendar/add/?responseMode=json` (form-urlencoded)
- **Удаление события календаря (сайт):** `POST https://easyfinance.ru/calendar/delete/?responseMode=json` (form-urlencoded: `id`, `chain`)
- **Обратная связь:** `POST https://easyfinance.ru/feedback/add_message/?responseMode=json` (form-urlencoded: `title`, `msg`, `email`)

---

## 15. Чек-лист «ничего не забыто»

Методы, реально вызываемые приложением (полный список):
`accounts.get`, `accounts.post`, `accounts.set`, `operations.get`,
`operations.post`, `operations.set`, `categories.get`, `categories.post`,
`categories.set`, `tags.get`, `tags.post`, `tags.set`, `targets.get`,
`targets.post`, `targets.set`, `budget.get`, `budget.categoriesget`,
`budget.categoriespost`, `budget.categoriesset`, `calendar.get`, `calendar.post`,
`calendar.set`, `calendar.delete`, `calendar.accept`, `operationPatterns.get`,
`operationPatterns.post`, `operationPatterns.set`, `currencies.get`,
`systemCategories.get`, `users.get`. А также OAuth (`buildOAuthCodeUrl`,
`exchangeCodeForToken`) и веб-эндпоинты (§14).

**Методов `*.delete` (accounts/categories/tags/operationPatterns) в API нет** —
удаление везде делается через соответствующий `*.set` с проставленным
`deleted_at` (или `state="2"` для счетов).
