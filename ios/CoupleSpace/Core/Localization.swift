import SwiftUI
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case ru
    case zhHant = "zh_Hant"
    case en

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .ru: return "RU"
        case .zhHant: return "繁中"
        case .en: return "EN"
        }
    }

    /// Локаль для дат и календаря.
    var locale: Locale {
        switch self {
        case .ru: return Locale(identifier: "ru_RU")
        case .zhHant: return Locale(identifier: "zh_Hant_MO")
        case .en: return Locale(identifier: "en_US")
        }
    }

    static var deviceDefault: AppLanguage {
        let preferred = (Locale.preferredLanguages.first ?? "en").lowercased()
        if preferred.hasPrefix("ru") { return .ru }
        if preferred.hasPrefix("zh") { return .zhHant }
        return .en
    }
}

@Observable
final class LocalizationManager {
    private static let storageKey = "app.language"

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            language = .deviceDefault
        }
    }

    func t(_ key: L) -> String {
        guard let entry = L.table[key] else { return key.rawValue }
        switch language {
        case .ru: return entry.ru
        case .zhHant: return entry.zh
        case .en: return entry.en
        }
    }

    var locale: Locale { language.locale }

    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        cal.timeZone = .current
        return cal
    }

    /// Слово «дней» с правильным склонением.
    func daysWord(_ n: Int) -> String {
        switch language {
        case .zhHant: return "天"
        case .en: return n == 1 ? "day" : "days"
        case .ru:
            let mod10 = n % 10, mod100 = n % 100
            if mod10 == 1 && mod100 != 11 { return "день" }
            if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "дня" }
            return "дней"
        }
    }

    func progress(_ current: Int, _ total: Int) -> String {
        switch language {
        case .ru: return "\(current) из \(total)"
        case .zhHant: return "第 \(current) / \(total) 題"
        case .en: return "\(current) of \(total)"
        }
    }

    func formatted(_ date: Date, template: String) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate(template)
        let s = f.string(from: date)
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

// MARK: - Strings (ru / 繁中 / en)

enum L: String {
    // Common
    case save, cancel, done, delete, edit, copy, copied, partner, me
    // Greeting
    case goodMorning, goodAfternoon, goodEvening
    // Tabs
    case tabHome, tabQuiz, tabCalendar
    // Home
    case countdownTitle, countdownEmpty, countdownAction, today, tomorrow, daysLeftSuffix
    case moodTitle, moodNotSet, moodTapToSet, moodSheetTitle, moodStatusPlaceholder
    case qotdTitle, qotdAnswer, qotdAllDone
    // Quiz
    case quizQuestions, quizOurAnswers, quizAll, quizAnswerToSee, quizNoAnswerYet
    case quizYourAnswer, quizOpenPlaceholder, quizSend, quizNext, quizPrevious, quizOr
    case quizArchiveEmpty, quizChangeAnswer
    // Calendar
    case addPlan, noPlans, newPlan, plan, planTitle, planDate, planTime, planHasTime, planCategory, planNote
    case catFood, catWalk, catTrip, catSpecial
    case wishlist, addIdea, newIdea, idea, toCalendar, scheduled, wishlistEmpty
    // Settings
    case settings, name, language, security, faceID, changePin, currentPin, newPin, repeatPin
    case pinMismatch, pinWrong, pinChanged, room, roomCode, roomHint, share
    case syncOn, syncOff, leaveRoom, leaveRoomConfirm
    // Lock
    case enterPin, wrongPin, useFaceID, unlockReason, lockHint
    // Onboarding
    case onbTitle, onbSubtitle, whoAreYou, partnerA, partnerB, yourName, createRoom, joinRoom
    case roomCodePlaceholder, continueAction, pinSetupHint, createPin, confirmPin, pinsDontMatch
    // v2: Coupons
    case tabSurprises, coupons, couponsForMe, couponsFromMe, newCoupon, addCoupon, couponTitle, couponDescription
    case couponIdeas, scratchHint, couponUse, couponUsed, couponNotOpened, couponOpened, couponHidden
    case couponsEmptyForMe, couponsEmptyFromMe, couponUseConfirm, couponFrom, couponFor, couponGive
    // v2: Reactions & comments
    case commentPlaceholder
    // v2: Swipe Match & Wheel
    case pickTogether, wheel, swipeTitle, swipeYes, swipeLater, swipeNeedIdeas, swipeWaiting, swipeNewRound
    case match, matchSubtitle, addToday, chooseDate, addedToCalendar
    case wheelTitle, wheelSpin, wheelOptionPlaceholder, wheelNeedOptions, wheelResult, wheelFromJar, wheelOptions
    // v2: Hug & care
    case hugTitle, hugHint, hugSending, hugPartnerHolding, hugTogether
    case moodStatus, sendSupport, careSakura, careHearts, careHug, careReceived
    // v2: Guess mode & rewards
    case guessTab, guessTitle, guessRoundOfWeek, guessStepSelf, guessStepPartner, guessWaiting
    case guessResults, guessRoundStars, guessStarsTotal, guessRight, guessWrong, guessNextRound
    case rewards, rewardsHint, starsToUnlock, iconClassic, iconSakura, iconLavender, iconNight, iconInUse, useIcon

    struct Entry { let ru: String; let zh: String; let en: String }

    static let table: [L: Entry] = [
        .save: .init(ru: "Сохранить", zh: "儲存", en: "Save"),
        .cancel: .init(ru: "Отмена", zh: "取消", en: "Cancel"),
        .done: .init(ru: "Готово", zh: "完成", en: "Done"),
        .delete: .init(ru: "Удалить", zh: "刪除", en: "Delete"),
        .edit: .init(ru: "Изменить", zh: "修改", en: "Edit"),
        .copy: .init(ru: "Скопировать", zh: "複製", en: "Copy"),
        .copied: .init(ru: "Скопировано", zh: "已複製", en: "Copied"),
        .partner: .init(ru: "Партнёр", zh: "另一半", en: "Partner"),
        .me: .init(ru: "Я", zh: "我", en: "Me"),

        .goodMorning: .init(ru: "Доброе утро", zh: "早晨", en: "Good morning"),
        .goodAfternoon: .init(ru: "Добрый день", zh: "午安", en: "Good afternoon"),
        .goodEvening: .init(ru: "Добрый вечер", zh: "晚上好", en: "Good evening"),

        .tabHome: .init(ru: "Главная", zh: "主頁", en: "Home"),
        .tabQuiz: .init(ru: "Опрос", zh: "問答", en: "Quiz"),
        .tabCalendar: .init(ru: "Календарь", zh: "日曆", en: "Calendar"),

        .countdownTitle: .init(ru: "До следующего плана", zh: "距離下一個計劃", en: "Until our next plan"),
        .countdownEmpty: .init(ru: "Пока ничего не запланировано", zh: "暫時還沒有計劃", en: "Nothing planned yet"),
        .countdownAction: .init(ru: "Запланировать", zh: "去安排", en: "Plan something"),
        .today: .init(ru: "Сегодня", zh: "今天", en: "Today"),
        .tomorrow: .init(ru: "Завтра", zh: "明天", en: "Tomorrow"),
        .daysLeftSuffix: .init(ru: "осталось", zh: "還有", en: "to go"),

        .moodTitle: .init(ru: "Настроение", zh: "心情", en: "Mood"),
        .moodNotSet: .init(ru: "Пока не выбрано", zh: "還未設定", en: "Not set yet"),
        .moodTapToSet: .init(ru: "Нажми, чтобы выбрать", zh: "點一下設定", en: "Tap to set"),
        .moodSheetTitle: .init(ru: "Как ты сейчас?", zh: "你現在感覺如何？", en: "How are you feeling?"),
        .moodStatusPlaceholder: .init(ru: "Пара слов…", zh: "說幾個字…", en: "A few words…"),

        .qotdTitle: .init(ru: "Вопрос дня", zh: "每日一問", en: "Question of the day"),
        .qotdAnswer: .init(ru: "Ответить", zh: "去回答", en: "Answer"),
        .qotdAllDone: .init(ru: "Все вопросы уже отвечены", zh: "所有問題都回答完了", en: "All questions are answered"),

        .quizQuestions: .init(ru: "Вопросы", zh: "問題", en: "Questions"),
        .quizOurAnswers: .init(ru: "Наши ответы", zh: "我們的答案", en: "Our answers"),
        .quizAll: .init(ru: "Все", zh: "全部", en: "All"),
        .quizAnswerToSee: .init(ru: "Ответь, чтобы увидеть ответ партнёра", zh: "回答後就可以看到對方的答案", en: "Answer to see your partner's answer"),
        .quizNoAnswerYet: .init(ru: "Пока без ответа", zh: "還未回答", en: "No answer yet"),
        .quizYourAnswer: .init(ru: "Твой ответ", zh: "你的答案", en: "Your answer"),
        .quizOpenPlaceholder: .init(ru: "Напиши свой ответ…", zh: "寫下你的答案…", en: "Write your answer…"),
        .quizSend: .init(ru: "Отправить", zh: "送出", en: "Send"),
        .quizNext: .init(ru: "Дальше", zh: "下一題", en: "Next"),
        .quizPrevious: .init(ru: "Назад", zh: "上一題", en: "Back"),
        .quizOr: .init(ru: "или", zh: "還是", en: "or"),
        .quizArchiveEmpty: .init(ru: "Здесь появятся вопросы, на которые вы ответили", zh: "你們回答過的問題會在這裡出現", en: "Questions you've answered will appear here"),
        .quizChangeAnswer: .init(ru: "Изменить ответ", zh: "修改答案", en: "Change answer"),

        .addPlan: .init(ru: "+ Добавить план", zh: "+ 新增計劃", en: "+ Add plan"),
        .noPlans: .init(ru: "На этот день планов нет", zh: "這天還沒有計劃", en: "No plans for this day"),
        .newPlan: .init(ru: "Новый план", zh: "新計劃", en: "New plan"),
        .plan: .init(ru: "План", zh: "計劃", en: "Plan"),
        .planTitle: .init(ru: "Название", zh: "名稱", en: "Title"),
        .planDate: .init(ru: "Дата", zh: "日期", en: "Date"),
        .planTime: .init(ru: "Время", zh: "時間", en: "Time"),
        .planHasTime: .init(ru: "Указать время", zh: "設定時間", en: "Set a time"),
        .planCategory: .init(ru: "Категория", zh: "類別", en: "Category"),
        .planNote: .init(ru: "Заметка", zh: "備註", en: "Note"),
        .catFood: .init(ru: "Еда / Кафе", zh: "美食／咖啡店", en: "Food / Café"),
        .catWalk: .init(ru: "Прогулка", zh: "散步", en: "Walk"),
        .catTrip: .init(ru: "Поездка", zh: "旅行", en: "Trip"),
        .catSpecial: .init(ru: "Особый день", zh: "特別的日子", en: "Special day"),
        .wishlist: .init(ru: "Копилка идей", zh: "點子收集箱", en: "Idea jar"),
        .addIdea: .init(ru: "+ Идея", zh: "+ 新點子", en: "+ Idea"),
        .newIdea: .init(ru: "Новая идея", zh: "新點子", en: "New idea"),
        .idea: .init(ru: "Идея", zh: "點子", en: "Idea"),
        .toCalendar: .init(ru: "В календарь", zh: "加入日曆", en: "To calendar"),
        .scheduled: .init(ru: "Запланировано", zh: "已安排", en: "Scheduled"),
        .wishlistEmpty: .init(ru: "Складывайте сюда места, фильмы и идеи на потом", zh: "把想去的地方、想看的電影和各種點子放在這裡", en: "Save places, films and ideas for later"),

        .settings: .init(ru: "Настройки", zh: "設定", en: "Settings"),
        .name: .init(ru: "Имя", zh: "名字", en: "Name"),
        .language: .init(ru: "Язык", zh: "語言", en: "Language"),
        .security: .init(ru: "Защита", zh: "安全", en: "Security"),
        .faceID: .init(ru: "Вход по Face ID", zh: "使用 Face ID 解鎖", en: "Unlock with Face ID"),
        .changePin: .init(ru: "Сменить PIN-код", zh: "更改 PIN 碼", en: "Change PIN"),
        .currentPin: .init(ru: "Текущий PIN-код", zh: "目前的 PIN 碼", en: "Current PIN"),
        .newPin: .init(ru: "Новый PIN-код", zh: "新 PIN 碼", en: "New PIN"),
        .repeatPin: .init(ru: "Повтори новый PIN-код", zh: "再輸入一次新 PIN 碼", en: "Repeat new PIN"),
        .pinMismatch: .init(ru: "Новые коды не совпадают", zh: "兩次輸入的新密碼不一樣", en: "New PINs don't match"),
        .pinWrong: .init(ru: "Текущий код неверный", zh: "目前的 PIN 碼不正確", en: "Current PIN is wrong"),
        .pinChanged: .init(ru: "PIN-код изменён", zh: "已更改 PIN 碼", en: "PIN changed"),
        .room: .init(ru: "Общая комната", zh: "共用房間", en: "Shared room"),
        .roomCode: .init(ru: "Код комнаты", zh: "房間代碼", en: "Room code"),
        .roomHint: .init(ru: "Введи этот код на втором iPhone, чтобы подключиться", zh: "在另一部 iPhone 輸入這個代碼就可以連接", en: "Enter this code on the second iPhone to connect"),
        .share: .init(ru: "Поделиться", zh: "分享", en: "Share"),
        .syncOn: .init(ru: "Синхронизация через Firebase включена", zh: "已透過 Firebase 同步", en: "Syncing with Firebase"),
        .syncOff: .init(ru: "Локальный режим: добавь GoogleService-Info.plist, чтобы включить синхронизацию", zh: "本機模式：加入 GoogleService-Info.plist 即可開啟同步", en: "Local mode: add GoogleService-Info.plist to enable sync"),
        .leaveRoom: .init(ru: "Выйти из комнаты", zh: "離開房間", en: "Leave room"),
        .leaveRoomConfirm: .init(ru: "Данные комнаты сохранятся, войти обратно можно по коду.", zh: "房間的資料會保留，可以用代碼重新加入。", en: "The room's data stays; you can rejoin with the code."),

        .enterPin: .init(ru: "Введи PIN-код", zh: "輸入 PIN 碼", en: "Enter your PIN"),
        .wrongPin: .init(ru: "Неверный код", zh: "密碼不正確", en: "Wrong PIN"),
        .useFaceID: .init(ru: "Войти с Face ID", zh: "使用 Face ID", en: "Use Face ID"),
        .unlockReason: .init(ru: "Открыть ваше пространство", zh: "打開你們的小天地", en: "Open your space"),
        .lockHint: .init(ru: "Только для нас двоих", zh: "只屬於我們兩個", en: "Just for the two of us"),

        .onbTitle: .init(ru: "Наше пространство", zh: "我們的小天地", en: "Our little space"),
        .onbSubtitle: .init(ru: "Создай комнату или подключись к комнате партнёра", zh: "建立房間，或加入對方的房間", en: "Create a room or join your partner's"),
        .whoAreYou: .init(ru: "Кто ты?", zh: "你是哪一位？", en: "Who are you?"),
        .partnerA: .init(ru: "Парень", zh: "男朋友", en: "Boyfriend"),
        .partnerB: .init(ru: "Девушка", zh: "女朋友", en: "Girlfriend"),
        .yourName: .init(ru: "Твоё имя", zh: "你的名字", en: "Your name"),
        .createRoom: .init(ru: "Создать комнату", zh: "建立房間", en: "Create a room"),
        .joinRoom: .init(ru: "У меня есть код", zh: "我有代碼", en: "I have a code"),
        .roomCodePlaceholder: .init(ru: "Код комнаты", zh: "房間代碼", en: "Room code"),
        .continueAction: .init(ru: "Продолжить", zh: "繼續", en: "Continue"),
        .pinSetupHint: .init(ru: "Придумай 4-значный PIN-код: он нужен, чтобы открывать приложение. Его можно сменить в настройках.", zh: "設定一個 4 位數 PIN 碼，用來打開 App。之後可以在設定中更改。", en: "Choose a 4-digit PIN to open the app. You can change it later in Settings."),
        .createPin: .init(ru: "Придумай PIN-код", zh: "設定 PIN 碼", en: "Choose a PIN"),
        .confirmPin: .init(ru: "Повтори PIN-код", zh: "再輸入一次 PIN 碼", en: "Repeat the PIN"),
        .tabSurprises: .init(ru: "Сюрпризы", zh: "驚喜", en: "Surprises"),
        .coupons: .init(ru: "Купоны желаний", zh: "願望券", en: "Wish coupons"),
        .couponsForMe: .init(ru: "Для меня", zh: "給我的", en: "For me"),
        .couponsFromMe: .init(ru: "От меня", zh: "我送出的", en: "From me"),
        .newCoupon: .init(ru: "Новый купон", zh: "新願望券", en: "New coupon"),
        .addCoupon: .init(ru: "+ Подарить купон", zh: "+ 送一張願望券", en: "+ Give a coupon"),
        .couponTitle: .init(ru: "Что дарим?", zh: "送甚麼？", en: "What's the gift?"),
        .couponDescription: .init(ru: "Подробности (необязательно)", zh: "詳情（可選）", en: "Details (optional)"),
        .couponIdeas: .init(ru: "Идеи", zh: "靈感", en: "Ideas"),
        .scratchHint: .init(ru: "Сотри пальцем", zh: "用手指刮開", en: "Scratch to reveal"),
        .couponUse: .init(ru: "Использовать", zh: "使用", en: "Use it"),
        .couponUsed: .init(ru: "Использован", zh: "已使用", en: "Used"),
        .couponNotOpened: .init(ru: "Ещё не открыт", zh: "還未刮開", en: "Not opened yet"),
        .couponOpened: .init(ru: "Открыт", zh: "已刮開", en: "Opened"),
        .couponHidden: .init(ru: "Купон-сюрприз", zh: "驚喜願望券", en: "Surprise coupon"),
        .couponsEmptyForMe: .init(ru: "Пока купонов нет. Когда партнёр подарит купон, он появится здесь.", zh: "暫時沒有願望券。對方送你的時候會出現在這裡。", en: "No coupons yet. When your partner gives you one, it'll show up here."),
        .couponsEmptyFromMe: .init(ru: "Подари первый купон", zh: "送出第一張願望券吧", en: "Give your first coupon"),
        .couponUseConfirm: .init(ru: "Партнёру придёт уведомление.", zh: "對方會收到通知。", en: "Your partner will be notified."),
        .couponFrom: .init(ru: "От:", zh: "來自：", en: "From:"),
        .couponFor: .init(ru: "Для:", zh: "送給：", en: "For:"),
        .couponGive: .init(ru: "Подарить", zh: "送出", en: "Give"),
        .commentPlaceholder: .init(ru: "Написать приписку…", zh: "寫句小留言…", en: "Add a little note…"),
        .pickTogether: .init(ru: "Выбрать вместе", zh: "一起揀", en: "Pick together"),
        .wheel: .init(ru: "Колесо", zh: "轉盤", en: "Wheel"),
        .swipeTitle: .init(ru: "Куда пойдём?", zh: "我們去哪裡？", en: "Where shall we go?"),
        .swipeYes: .init(ru: "Хочу сегодня", zh: "今天想去", en: "Want today"),
        .swipeLater: .init(ru: "Не сейчас", zh: "下次吧", en: "Not now"),
        .swipeNeedIdeas: .init(ru: "Добавь в копилку хотя бы две идеи, чтобы выбирать вместе", zh: "先在點子收集箱加至少兩個點子，才可以一起揀", en: "Add at least two ideas to the jar to pick together"),
        .swipeWaiting: .init(ru: "Ты всё пролистал(а). Ждём, что выберет партнёр…", zh: "你已經揀完了，等對方揀…", en: "You're done. Waiting for your partner…"),
        .swipeNewRound: .init(ru: "Новый раунд", zh: "新一輪", en: "New round"),
        .match: .init(ru: "Match!", zh: "配對成功！", en: "It's a match!"),
        .matchSubtitle: .init(ru: "Вы оба хотите:", zh: "你們都想去：", en: "You both want:"),
        .addToday: .init(ru: "Добавить на сегодня", zh: "加到今天", en: "Add for today"),
        .chooseDate: .init(ru: "Выбрать дату", zh: "選擇日期", en: "Pick a date"),
        .addedToCalendar: .init(ru: "Добавлено в календарь", zh: "已加入日曆", en: "Added to calendar"),
        .wheelTitle: .init(ru: "Колесо фортуны", zh: "幸運轉盤", en: "Wheel of fortune"),
        .wheelSpin: .init(ru: "Крутить", zh: "轉！", en: "Spin"),
        .wheelOptionPlaceholder: .init(ru: "Добавить вариант…", zh: "新增選項…", en: "Add an option…"),
        .wheelNeedOptions: .init(ru: "Нужно от 2 до 8 вариантов", zh: "需要 2 至 8 個選項", en: "You need 2 to 8 options"),
        .wheelResult: .init(ru: "Выпало:", zh: "結果：", en: "It's:"),
        .wheelFromJar: .init(ru: "Из копилки", zh: "從收集箱", en: "From the jar"),
        .wheelOptions: .init(ru: "Варианты", zh: "選項", en: "Options"),
        .hugTitle: .init(ru: "Обнять на расстоянии", zh: "隔空擁抱", en: "Long-distance hug"),
        .hugHint: .init(ru: "Удерживай кружок, чтобы обнять", zh: "按住圓圈就可以擁抱對方", en: "Hold the circle to send a hug"),
        .hugSending: .init(ru: "Обнимаю… если вы будете держать вместе, телефоны почувствуют сердцебиение", zh: "擁抱中…兩個人一起按住，手機會一起心跳", en: "Hugging… hold together to feel a shared heartbeat"),
        .hugPartnerHolding: .init(ru: "обнимает тебя прямо сейчас — удерживай кружок в ответ", zh: "正在抱住你，按住圓圈回抱吧", en: "is hugging you right now — hold the circle to hug back"),
        .hugTogether: .init(ru: "Вы обнимаетесь 🤍", zh: "你們正在擁抱 🤍", en: "You're hugging 🤍"),
        .moodStatus: .init(ru: "Статус", zh: "狀態", en: "Status"),
        .sendSupport: .init(ru: "Отправить поддержку", zh: "送上關心", en: "Send some support"),
        .careSakura: .init(ru: "Сакура", zh: "櫻花", en: "Sakura"),
        .careHearts: .init(ru: "Сердечки", zh: "心心", en: "Hearts"),
        .careHug: .init(ru: "Обнимашки", zh: "抱抱", en: "Hugs"),
        .careReceived: .init(ru: "шлёт тебе поддержку", zh: "送你一點關心", en: "is sending you some love"),
        .guessTab: .init(ru: "Угадай", zh: "猜一猜", en: "Guess"),
        .guessTitle: .init(ru: "Насколько хорошо ты меня знаешь?", zh: "你有多了解我？", en: "How well do you know me?"),
        .guessRoundOfWeek: .init(ru: "Раунд недели", zh: "本週回合", en: "This week's round"),
        .guessStepSelf: .init(ru: "Сначала ответь за себя", zh: "先回答你自己的答案", en: "First, answer for yourself"),
        .guessStepPartner: .init(ru: "А что ответит {name}?", zh: "{name} 會怎樣答？", en: "What will {name} say?"),
        .guessWaiting: .init(ru: "Твои ответы сохранены. Ждём, когда {name} пройдёт раунд…", zh: "你已經完成了，等 {name} 完成這個回合…", en: "You're done. Waiting for {name} to finish the round…"),
        .guessResults: .init(ru: "Результаты", zh: "結果", en: "Results"),
        .guessRoundStars: .init(ru: "За раунд", zh: "本回合", en: "This round"),
        .guessStarsTotal: .init(ru: "наших звёздочек", zh: "我們的星星", en: "stars together"),
        .guessRight: .init(ru: "угадал(а)", zh: "猜中", en: "guessed"),
        .guessWrong: .init(ru: "мимо", zh: "猜錯", en: "missed"),
        .guessNextRound: .init(ru: "Новый раунд откроется в понедельник", zh: "新回合星期一開始", en: "A new round opens on Monday"),
        .rewards: .init(ru: "Награды", zh: "獎勵", en: "Rewards"),
        .rewardsHint: .init(ru: "Копите звёздочки вместе и открывайте новые иконки приложения", zh: "一起儲星星，解鎖新的 App 圖示", en: "Collect stars together to unlock new app icons"),
        .starsToUnlock: .init(ru: "Ещё {n} ★ до награды", zh: "還差 {n} ★", en: "{n} ★ to the next reward"),
        .iconClassic: .init(ru: "Классическая", zh: "經典", en: "Classic"),
        .iconSakura: .init(ru: "Сакура", zh: "櫻花", en: "Sakura"),
        .iconLavender: .init(ru: "Лаванда", zh: "薰衣草", en: "Lavender"),
        .iconNight: .init(ru: "Ночная", zh: "夜空", en: "Night"),
        .iconInUse: .init(ru: "Сейчас стоит", zh: "使用中", en: "In use"),
        .useIcon: .init(ru: "Поставить", zh: "使用", en: "Use"),
        .pinsDontMatch: .init(ru: "Коды не совпадают", zh: "兩次輸入的 PIN 碼不一樣", en: "The PINs don't match"),
    ]
}
