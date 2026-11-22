import SwiftUI

// MARK: - Partner

enum Partner: String, Codable, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"

    var id: String { rawValue }
    var other: Partner { self == .a ? .b : .a }
}

// MARK: - Quiz (формат couple_quiz_questions.json)

struct LocalizedText: Codable, Hashable {
    let ru: String
    let zh_Hant: String
    let en: String

    func callAsFunction(_ lang: AppLanguage) -> String {
        switch lang {
        case .ru: return ru
        case .zhHant: return zh_Hant
        case .en: return en
        }
    }
}

struct QuizCategory: Codable, Identifiable, Hashable {
    let id: String
    let title: LocalizedText
}

enum QuestionType: String, Codable {
    case eitherOr = "either_or"
    case open
}

struct QuizOption: Codable, Identifiable, Hashable {
    let id: String
    let ru: String
    let zh_Hant: String
    let en: String

    func text(_ lang: AppLanguage) -> String {
        switch lang {
        case .ru: return ru
        case .zhHant: return zh_Hant
        case .en: return en
        }
    }
}

struct QuizQuestion: Codable, Identifiable, Hashable {
    let id: String
    let category: String
    let type: QuestionType
    let prompt: LocalizedText
    let options: [QuizOption]?

    /// Текст ответа для показа: для either_or в ответе хранится id варианта ("a"/"b").
    func display(_ raw: String, lang: AppLanguage) -> String {
        if type == .eitherOr, let option = options?.first(where: { $0.id == raw }) {
            return option.text(lang)
        }
        return raw
    }
}

struct QuestionBankFile: Codable {
    let version: String
    let languages: [String]
    let categories: [QuizCategory]
    let questions: [QuizQuestion]
}

/// rooms/{roomId}/quizAnswers/{questionId}
struct QuizAnswer: Codable, Hashable {
    var questionId: String
    var category: String
    var type: String
    var answerA: String?
    var answerB: String?
    var updatedAt: Date
    var reactionA: String?   // reactions.partnerA
    var reactionB: String?   // reactions.partnerB

    func answer(for partner: Partner) -> String? {
        let value = partner == .a ? answerA : answerB
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    func reaction(for partner: Partner) -> String? {
        let value = partner == .a ? reactionA : reactionB
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    static let reactionChoices = ["🤍", "🥹", "😂", "✨", "🔥"]
}

/// rooms/{roomId}/quizAnswers/{questionId}/comments/{commentId}
struct QuizComment: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var senderId: Partner
    var text: String
    var createdAt: Date
}

// MARK: - Swipe Match (ТЗ v2, 2.1)

/// rooms/{roomId}/swipeSessions/{sessionId}
struct SwipeSession: Codable, Identifiable, Hashable {
    enum Status: String, Codable { case active, matched }

    var id: String = UUID().uuidString
    var status: Status = .active
    var votesA: [String: Bool] = [:]
    var votesB: [String: Bool] = [:]
    var matchedIdeaId: String?
    var createdAt: Date = Date()

    func votes(for partner: Partner) -> [String: Bool] {
        partner == .a ? votesA : votesB
    }

    /// Первая идея, которую оба свайпнули вправо.
    var mutualLike: String? {
        votesA.keys.sorted().first { votesA[$0] == true && votesB[$0] == true }
    }
}

// MARK: - Coupons (ТЗ v2, 2.3)

/// rooms/{roomId}/coupons/{couponId}
struct Coupon: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var description: String
    var emoji: String
    var createdBy: Partner
    var recipientId: Partner
    var isScratched: Bool = false
    var isRedeemed: Bool = false
    var redeemedAt: Date?
    var createdAt: Date = Date()

    static let emojiChoices = ["🎁", "💌", "🧋", "🎬", "🍜", "🥞", "💆", "🌸", "✈️", "🎶", "🍰", "🛍️"]

    struct Preset: Identifiable {
        let emoji: String
        let title: LocalizedText
        var id: String { title.en }
    }

    static let presets: [Preset] = [
        .init(emoji: "🎁", title: .init(ru: "Свидание-сюрприз", zh_Hant: "驚喜約會", en: "Surprise date")),
        .init(emoji: "🎬", title: .init(ru: "Выбор фильма без споров", zh_Hant: "今晚的電影由你決定", en: "Movie pick, no arguing")),
        .init(emoji: "🧋", title: .init(ru: "Любой бабл-ти за мой счёт", zh_Hant: "任何一杯珍珠奶茶我請", en: "Any bubble tea on me")),
        .init(emoji: "🥞", title: .init(ru: "Завтрак в постель", zh_Hant: "床上早餐", en: "Breakfast in bed")),
        .init(emoji: "💆", title: .init(ru: "Массаж 15 минут", zh_Hant: "15 分鐘按摩", en: "15-minute massage")),
        .init(emoji: "🍜", title: .init(ru: "Ужин, который готовлю я", zh_Hant: "我親手煮的晚餐", en: "Dinner cooked by me")),
    ]
}

// MARK: - Mood

struct Mood: Codable, Hashable {
    var emoji: String
    var text: String
    var updatedAt: Date
    var status: String? = nil   // ключ MoodStatus

    var moodStatus: MoodStatus? { status.flatMap(MoodStatus.init(rawValue:)) }

    static let choices = ["😊", "🥰", "😌", "🥳", "😴", "🤔", "😢", "😤", "🤒", "🍵", "💪", "🌧️", "✨", "🫶", "🍜", "📚"]
}

/// Пресеты статусов (ТЗ v2, 1.3): у части из них карточка тонируется,
/// а второму партнёру предлагается «Отправить поддержку».
enum MoodStatus: String, CaseIterable, Identifiable, Codable {
    case happy, lovey, calm, busy, missing, tired, stressed, sad, sick

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .lovey: return "🥰"
        case .calm: return "😌"
        case .busy: return "📚"
        case .missing: return "🥺"
        case .tired: return "😮‍💨"
        case .stressed: return "😣"
        case .sad: return "😢"
        case .sick: return "🤒"
        }
    }

    var tint: Color {
        switch self {
        case .happy: return Palette.champagne
        case .lovey: return Palette.sakura
        case .calm: return Color(hex: 0xCFE3DE)
        case .busy: return Palette.lavender
        case .missing: return Color(hex: 0xE3D3F0)
        case .tired: return Color(hex: 0xE8E1EA)
        case .stressed: return Color(hex: 0xF5CFC9)
        case .sad: return Color(hex: 0xD9E4F5)
        case .sick: return Color(hex: 0xE3EFE9)
        }
    }

    /// Статусы, при которых партнёру показывается «Отправить поддержку».
    var needsCare: Bool {
        switch self {
        case .missing, .tired, .stressed, .sad, .sick: return true
        default: return false
        }
    }

    /// Текст статуса; в русском род зависит от того, чей статус (A — парень, B — девушка).
    func title(_ lang: AppLanguage, owner: Partner) -> String {
        let male = owner == .a
        switch (self, lang) {
        case (.happy, .ru): return "Радуюсь"
        case (.happy, .zhHant): return "開心"
        case (.happy, .en): return "Happy"
        case (.lovey, .ru): return male ? "Влюблён" : "Влюблена"
        case (.lovey, .zhHant): return "甜蜜"
        case (.lovey, .en): return "In love"
        case (.calm, .ru): return "Спокойствие"
        case (.calm, .zhHant): return "平靜"
        case (.calm, .en): return "Calm"
        case (.busy, .ru): return male ? "Занят" : "Занята"
        case (.busy, .zhHant): return "忙碌中"
        case (.busy, .en): return "Busy"
        case (.missing, .ru): return "Скучаю"
        case (.missing, .zhHant): return "好想你"
        case (.missing, .en): return "Missing you"
        case (.tired, .ru): return male ? "Устал" : "Устала"
        case (.tired, .zhHant): return "好累"
        case (.tired, .en): return "Tired"
        case (.stressed, .ru): return "Нервничаю"
        case (.stressed, .zhHant): return "有點壓力"
        case (.stressed, .en): return "Stressed"
        case (.sad, .ru): return "Грустно"
        case (.sad, .zhHant): return "有點難過"
        case (.sad, .en): return "A bit sad"
        case (.sick, .ru): return male ? "Приболел" : "Приболела"
        case (.sick, .zhHant): return "不舒服"
        case (.sick, .en): return "Not feeling well"
        }
    }
}

/// rooms/{roomId}/carePings/{pingId}
struct CarePing: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable { case sakura, hearts, hugSparkle = "hug_sparkle" }

    var id: String = UUID().uuidString
    var type: Kind
    var senderId: Partner
    var createdAt: Date = Date()
    var seen: Bool = false

    var emoji: String {
        switch type {
        case .sakura: return "🌸"
        case .hearts: return "💗"
        case .hugSparkle: return "🤗"
        }
    }
}

/// rooms/{roomId}/presence/hug
struct HugPresence: Codable, Hashable {
    var partnerAHolding = false
    var partnerBHolding = false
    var partnerAHoldingAt: Date?
    var partnerBHoldingAt: Date?
    var lastTriggeredBy: Partner?
    var updatedAt: Date?

    /// Удержание считается живым, если обновлялось за последние 15 секунд (на случай обрыва связи).
    func isHolding(_ partner: Partner, now: Date = Date()) -> Bool {
        let holding = partner == .a ? partnerAHolding : partnerBHolding
        let at = partner == .a ? partnerAHoldingAt : partnerBHoldingAt
        guard holding, let at else { return false }
        return now.timeIntervalSince(at) < 15
    }
}

// MARK: - Calendar

enum PlanCategory: String, Codable, CaseIterable, Identifiable {
    case food, walk, trip, special

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .food: return Palette.food
        case .walk: return Palette.walk
        case .trip: return Palette.trip
        case .special: return Palette.special
        }
    }

    var titleKey: L {
        switch self {
        case .food: return .catFood
        case .walk: return .catWalk
        case .trip: return .catTrip
        case .special: return .catSpecial
        }
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .walk: return "figure.walk"
        case .trip: return "airplane"
        case .special: return "heart.fill"
        }
    }
}

/// rooms/{roomId}/events/{eventId}
struct PlanEvent: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var date: String          // YYYY-MM-DD
    var time: String?         // HH:mm
    var category: PlanCategory
    var note: String
    var createdBy: Partner
}

/// rooms/{roomId}/ideas/{ideaId}
struct Idea: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var category: PlanCategory
    var note: String
    var createdBy: Partner
    var isScheduled: Bool = false
}

/// rooms/{roomId}.meta
struct RoomMeta: Codable, Hashable {
    var createdAt: Date?
    var partnerAName: String?
    var partnerBName: String?
    var langA: String?
    var langB: String?
    var pinHash: String?

    func name(for partner: Partner) -> String? {
        let value = partner == .a ? partnerAName : partnerBName
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

// MARK: - Day keys

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    static func string(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ key: String) -> Date? { formatter.date(from: key) }

    static func timeString(_ date: Date) -> String { timeFormatter.string(from: date) }
    static func time(_ value: String) -> Date? { timeFormatter.date(from: value) }

    /// Сколько дней от сегодня до даты (0 — сегодня).
    static func daysFromToday(_ key: String) -> Int? {
        guard let target = date(key) else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: target)).day
    }
}
