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

    func answer(for partner: Partner) -> String? {
        let value = partner == .a ? answerA : answerB
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

// MARK: - Mood

struct Mood: Codable, Hashable {
    var emoji: String
    var text: String
    var updatedAt: Date

    static let choices = ["😊", "🥰", "😌", "🥳", "😴", "🤔", "😢", "😤", "🤒", "🍵", "💪", "🌧️", "✨", "🫶", "🍜", "📚"]
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
