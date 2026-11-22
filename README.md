# Couple Space

Личное iOS-приложение для двоих: опрос со взаимным открытием ответов, общий календарь, копилка идей и настроение. Интерфейс на трёх языках: RU / 繁中 / EN. Полное ТЗ лежит в [`docs/TZ.md`](docs/TZ.md).

```
ios/                     iOS-приложение (SwiftUI, iOS 17+)
  CoupleSpace.xcodeproj
  CoupleSpace/
    App/                 точка входа, AppDelegate (push)
    Core/                тема, локализация, PIN/Face ID
    Models/              модели и банк вопросов
    Services/            Firestore / локальный режим, push, задел под виджет
    ViewModels/          AppSession, RoomStore, Quiz/Calendar VM
    Views/               экраны
    Resources/couple_quiz_questions.json
  Config/                Info.plist, entitlements
functions/               Cloud Functions: push о новых ответах, планах и идеях
firestore.rules          правила доступа
index.html               старый сайт-опрос (GitHub Pages), не мешает приложению
```

## 1. Первый запуск (без Firebase)

1. Нужен Mac с **Xcode 16** или новее.
2. Открой `ios/CoupleSpace.xcodeproj`. Xcode сам скачает Firebase SDK (Swift Package Manager), на это уйдёт пара минут.
3. Открой **Signing & Capabilities**, выбери свою **Team**. Если Xcode ругается на Bundle ID, поменяй `com.kinerma.couplespace` на свой.
4. Запусти на симуляторе или iPhone.

Пока в проекте нет `GoogleService-Info.plist`, приложение работает в **локальном режиме**: всё сохраняется на одном устройстве. Так удобно проверить интерфейс. При первом входе выбираешь «Парень» или «Девушка», имя и придумываешь свой 4-значный PIN-код.

## 2. Подключение Firebase (синхронизация двух iPhone)

1. Зайди на [console.firebase.google.com](https://console.firebase.google.com) и создай проект.
2. **Add app → iOS**, Bundle ID тот же, что в Xcode. Скачай `GoogleService-Info.plist` и положи в `ios/CoupleSpace/`. Папка синхронизируется с Xcode, добавлять файл вручную не нужно. В git он не попадёт.
3. **Build → Authentication → Sign-in method** → включи **Anonymous**.
4. **Build → Firestore Database → Create database**, регион `asia-east2 (Hong Kong)`.
5. Залей правила (нужен [Firebase CLI](https://firebase.google.com/docs/cli)):
   ```bash
   npm install -g firebase-tools
   firebase login
   firebase use --add          # выбери свой проект
   firebase deploy --only firestore:rules
   ```

После этого запусти приложение на двух iPhone. На первом выбери «Создать комнату», на втором — «У меня есть код» и введи код из настроек первого.

## 3. Push-уведомления

1. В [Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list) создай ключ с **Apple Push Notifications service (APNs)** и скачай `.p8`.
2. В Firebase открой **Project settings → Cloud Messaging → Apple app configuration** и загрузи ключ: Key ID и Team ID.
3. Задеплой функции. Нужен тариф **Blaze**: он с оплатой по факту, но для двоих укладывается в бесплатный лимит.
   ```bash
   cd functions && npm install && cd ..
   firebase deploy --only functions
   ```

Уведомления приходят, когда партнёр впервые ответил на вопрос, добавил план или идею. Язык уведомления совпадает с языком интерфейса получателя.

## 4. TestFlight

1. В Xcode: **Product → Archive** (устройство: *Any iOS Device*).
2. **Distribute App → App Store Connect → Upload**.
3. В [App Store Connect](https://appstoreconnect.apple.com) создай приложение с тем же Bundle ID. После обработки сборки добавь второго партнёра в **TestFlight → Internal/External Testing**.

Нужен платный аккаунт Apple Developer Program.

## Что где в коде

| Функция из ТЗ | Файл |
|---|---|
| Цвета, стекло, кнопки, шрифты | `Core/Theme.swift` |
| Языки и все строки интерфейса | `Core/Localization.swift` |
| PIN в Keychain, Face ID | `Core/Security.swift`, `Views/LockScreenView.swift` |
| Схема Firestore | `Services/FirestoreBackend.swift` |
| Mutual Reveal | `Views/QuizView.swift` → `PartnerAnswerView` |
| Календарь и копилка идей | `Views/CalendarView.swift` |
| Задел под виджет | `Services/WidgetBridge.swift` |

## Интерактивные фичи v2

ТЗ: [`docs/TZ-v2.md`](docs/TZ-v2.md). Модули внедряются по одному.

- [x] **Модуль 1.** Скретч-купоны (вкладка «Сюрпризы», `Views/CouponsView.swift`, `Views/Components/ScratchCard.swift`) и реакции/приписки в «Наших ответах» (`Views/AnswerThreadView.swift`)
- [x] **Модуль 2.** «Тиндер» для идей (`Views/SwipeMatchView.swift`) и колесо фортуны (`Views/WheelOfFortuneView.swift`) — кнопки «Выбрать вместе» и «Колесо» в Копилке идей
- [x] **Модуль 3.** Статусы настроения с оттенком карточки и «Отправить поддержку» (`Views/HomeView.swift`, `CareOverlay` в `Views/RootView.swift`), «Обнять на расстоянии» (`Views/HugCard.swift`, `Services/HeartbeatHaptics.swift`)
- [x] **Модуль 4.** «Насколько хорошо ты меня знаешь?» — вкладка «Угадай» в опросе (`Views/GuessModeView.swift`), общие звёздочки и альтернативные иконки (`AppIcon-Sakura/Lavender/Night` в Assets)
- [ ] Модуль 5. Полароиды с проявкой и капсула времени
- [ ] Модуль 6. Карта воспоминаний и Doodle-виджет

После изменений в `functions/` их нужно задеплоить заново: `firebase deploy --only functions`.

Чтобы добавить вопросы, отредактируй `ios/CoupleSpace/Resources/couple_quiz_questions.json`: у каждого вопроса тексты на трёх языках, а `type` — `either_or` или `open`.
