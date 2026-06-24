# EasyFinance App

Мобильное приложение для учёта финансов — аналог EasyFinance.ru.

## Функционал

- **Главная**: баланс, доходы/расходы за месяц, финансовое состояние
- **Учёт**: список операций с фильтрацией по типу
- **План**: бюджеты по категориям и финансовые цели
- **Календарь**: события, платежи, напоминания
- **Отчёты**: аналитика доходов/расходов по категориям
- **Ещё**: EasyBank, рекомендации, ИИ-ассистент, настройки

## Запуск

```bash
# Установка зависимостей
flutter pub get

# Запуск на устройстве/эмуляторе
flutter run

# Сборка APK
flutter build apk --release
```

## GitHub Actions (автосборка APK)

1. Создайте репозиторий на GitHub
2. Залейте код:
   ```bash
   git init
   git add .
   git commit -m "initial commit"
   git remote add origin https://github.com/ВАШ_ЛОГИН/НАЗВАНИЕ.git
   git push -u origin main
   ```
3. Перейдите в Actions → выберите "Build APK" → Run workflow
4. Готовый APK будет в артефактах (`release-apks`)

## Структура

```
lib/
├── main.dart                  # Точка входа
├── theme/                     # Тема (цвета, стили)
├── models/                    # Модели данных
├── services/                  # Мок-данные
├── store/                     # Состояние (Provider)
├── utils/                     # Форматирование, расчёты
├── navigation/                # Маршрутизация
├── components/                # UI компоненты
│   ├── common/                # Кнопки, карточки, инпуты
│   ├── operations/            # Элементы операций
│   ├── charts/                # Графики (Gauge)
│   └── home/                  # Блоки главной
└── screens/                   # Экраны
    ├── auth/                  # Логин
    ├── home/                  # Главная
    ├── operations/            # Операции
    ├── budget/                # Бюджет
    ├── goals/                 # Цели
    ├── calendar/              # Календарь
    ├── reports/               # Отчёты
    └── more/                  # Ещё (банк, ИИ, настройки)
```

## Дизайн

Дизайн основан на [easyFinance_app2](https://github.com/KtifPMI/easyFinance_app2).
Цветовая схема: зелёный (#2E7D32), белый, серый.
