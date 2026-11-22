import SwiftUI
import Observation

/// Общие данные комнаты, синхронизированные между двумя iPhone.
@Observable
final class RoomStore {
    private(set) var meta = RoomMeta()
    private(set) var moods: [Partner: Mood] = [:]
    private(set) var answers: [String: QuizAnswer] = [:]
    private(set) var events: [PlanEvent] = []
    private(set) var ideas: [Idea] = []

    private(set) var connectedRoomId: String?
    @ObservationIgnored private let backend: RoomBackend

    var isCloud: Bool { backend.isCloud }

    init() {
        backend = FirebaseBootstrap.isConfigured ? FirestoreBackend() : LocalBackend()
    }

    // MARK: Connection

    func connect(roomId: String) {
        guard connectedRoomId != roomId else { return }
        connectedRoomId = roomId
        meta = RoomMeta(); moods = [:]; answers = [:]; events = []; ideas = []
        backend.connect(roomId: roomId) { [weak self] update in
            DispatchQueue.main.async { self?.apply(update) }
        }
    }

    func disconnect() {
        backend.disconnect()
        connectedRoomId = nil
        meta = RoomMeta(); moods = [:]; answers = [:]; events = []; ideas = []
    }

    private func apply(_ update: RoomUpdate) {
        switch update {
        case .meta(let value): meta = value
        case .moods(let value): moods = value
        case .answers(let value): answers = value
        case .events(let value): events = value
        case .ideas(let value): ideas = value
        }
    }

    // MARK: Writes

    func createRoom() { backend.createRoom() }

    func setProfile(name: String, language: AppLanguage, for partner: Partner) {
        backend.setProfile(name: name, language: language, for: partner)
    }

    func setPinHash(_ hash: String) { backend.setPinHash(hash) }

    func setMood(emoji: String, text: String, for partner: Partner) {
        backend.setMood(Mood(emoji: emoji, text: text, updatedAt: Date()), for: partner)
    }

    func answer(_ value: String, to question: QuizQuestion, as partner: Partner) {
        backend.setAnswer(value, question: question, for: partner)
    }

    func save(_ event: PlanEvent) { backend.saveEvent(event) }
    func delete(_ event: PlanEvent) { backend.deleteEvent(id: event.id) }
    func save(_ idea: Idea) { backend.saveIdea(idea) }
    func delete(_ idea: Idea) { backend.deleteIdea(id: idea.id) }

    /// «В календарь»: идея → план на выбранную дату, идея помечается как запланированная.
    func schedule(_ idea: Idea, on date: Date, by partner: Partner) {
        backend.saveEvent(PlanEvent(
            title: idea.title,
            date: DayKey.string(date),
            time: nil,
            category: idea.category,
            note: idea.note,
            createdBy: partner
        ))
        var updated = idea
        updated.isScheduled = true
        backend.saveIdea(updated)
    }

    // MARK: Queries

    func answer(for question: QuizQuestion) -> QuizAnswer? { answers[question.id] }

    func myAnswer(_ question: QuizQuestion, me: Partner) -> String? {
        answers[question.id]?.answer(for: me)
    }

    func partnerName(_ partner: Partner) -> String? { meta.name(for: partner) }

    var nextEvent: PlanEvent? {
        let today = DayKey.string(Date())
        return events
            .filter { $0.date >= today }
            .sorted { ($0.date, $0.time ?? "") < ($1.date, $1.time ?? "") }
            .first
    }

    func events(on date: Date) -> [PlanEvent] {
        let key = DayKey.string(date)
        return events
            .filter { $0.date == key }
            .sorted { ($0.time ?? "") < ($1.time ?? "") }
    }

    func categories(on key: String) -> [PlanCategory] {
        let present = Set(events.filter { $0.date == key }.map(\.category))
        return PlanCategory.allCases.filter { present.contains($0) }
    }

    /// Вопрос дня: стабильный в течение дня, выбирается из тех, на которые я ещё не ответил(а).
    func questionOfTheDay(me: Partner) -> QuizQuestion? {
        let pending = QuestionBank.shared.questions.filter { myAnswer($0, me: me) == nil }
        guard !pending.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return pending[day % pending.count]
    }

    /// Архив: все вопросы, на которые ответил хотя бы один из нас, новые сверху.
    var answeredQuestions: [ArchiveItem] {
        answers.values
            .filter { $0.answerA != nil || $0.answerB != nil }
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { answer in
                QuestionBank.shared.question(id: answer.questionId).map { ArchiveItem(question: $0, answer: answer) }
            }
    }

    func updateWidgetSnapshot(me: Partner) {
        WidgetSnapshot(
            nextEventTitle: nextEvent?.title,
            nextEventDate: nextEvent?.date,
            myMoodEmoji: moods[me]?.emoji,
            partnerMoodEmoji: moods[me.other]?.emoji,
            partnerName: meta.name(for: me.other)
        ).save()
    }
}

struct ArchiveItem: Identifiable {
    let question: QuizQuestion
    let answer: QuizAnswer
    var id: String { question.id }
}
