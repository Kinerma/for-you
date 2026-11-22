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
    case roomCodePlaceholder, continueAction, defaultPinNote

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
        .partnerA: .init(ru: "Партнёр А", zh: "伴侶 A", en: "Partner A"),
        .partnerB: .init(ru: "Партнёр Б", zh: "伴侶 B", en: "Partner B"),
        .yourName: .init(ru: "Твоё имя", zh: "你的名字", en: "Your name"),
        .createRoom: .init(ru: "Создать комнату", zh: "建立房間", en: "Create a room"),
        .joinRoom: .init(ru: "У меня есть код", zh: "我有代碼", en: "I have a code"),
        .roomCodePlaceholder: .init(ru: "Код комнаты", zh: "房間代碼", en: "Room code"),
        .continueAction: .init(ru: "Продолжить", zh: "繼續", en: "Continue"),
        .defaultPinNote: .init(ru: "PIN-код по умолчанию: 1122. Его можно сменить в настройках.", zh: "預設 PIN 碼是 1122，可以在設定中更改。", en: "The default PIN is 1122. You can change it in Settings."),
    ]
}
