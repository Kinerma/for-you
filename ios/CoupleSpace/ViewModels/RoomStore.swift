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
    private(set) var coupons: [Coupon] = []
    private(set) var swipeSessions: [SwipeSession] = []
    private(set) var hug = HugPresence()
    private(set) var carePings: [CarePing] = []
    private(set) var guesses: [String: GuessEntry] = [:]
    private(set) var latestInteraction: Interaction?
    private(set) var dailyMoment: DailyMoment?

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
        meta = RoomMeta(); moods = [:]; answers = [:]; events = []; ideas = []; coupons = []; swipeSessions = []; hug = HugPresence(); carePings = []; guesses = [:]; latestInteraction = nil; dailyMoment = nil
        backend.connect(roomId: roomId) { [weak self] update in
            DispatchQueue.main.async { self?.apply(update) }
        }
    }

    func disconnect() {
        backend.disconnect()
        connectedRoomId = nil
        meta = RoomMeta(); moods = [:]; answers = [:]; events = []; ideas = []; coupons = []; swipeSessions = []
        hug = HugPresence(); carePings = []; guesses = [:]; latestInteraction = nil; dailyMoment = nil
    }

    private func apply(_ update: RoomUpdate) {
        switch update {
        case .meta(let value): meta = value
        case .moods(let value): moods = value
        case .answers(let value): answers = value
        case .events(let value): events = value
        case .ideas(let value): ideas = value
        case .coupons(let value): coupons = value
        case .swipeSessions(let value):
            swipeSessions = value
            detectSwipeMatch()
        case .hug(let value): hug = value
        case .carePings(let value): carePings = value
        case .guesses(let value):
            guesses = Dictionary(uniqueKeysWithValues: value.map { ($0.id, $0) })
            completeFinishedGuesses()
        case .interaction(let value): latestInteraction = value
        case .dailyMoment(let value): dailyMoment = value
        }
    }

    // MARK: Writes

    func createRoom() { backend.createRoom() }

    func setProfile(name: String, language: AppLanguage, for partner: Partner) {
        backend.setProfile(name: name, language: language, for: partner)
    }

    func setPinHash(_ hash: String) { backend.setPinHash(hash) }

    func setMood(emoji: String, text: String, status: MoodStatus? = nil,
                 energy: Int? = nil, need: NeedTag? = nil, for partner: Partner) {
        backend.setMood(Mood(emoji: emoji, text: text, updatedAt: Date(), status: status?.rawValue,
                             energyLevel: energy, needTag: need?.rawValue), for: partner)
    }

    // MARK: Home (обновлённая главная)

    /// Быстрое обновление заряда со шкалы на карточке — остальные поля настроения сохраняются.
    func updateEnergy(_ level: Int, for partner: Partner) {
        let current = moods[partner]
        backend.setMood(Mood(emoji: current?.emoji ?? "😊", text: current?.text ?? "", updatedAt: Date(),
                             status: current?.status, energyLevel: level, needTag: current?.needTag), for: partner)
    }

    func setRelationshipStart(_ date: Date) { backend.setRelationshipStart(date) }

    /// Импульс поддержки по тапу на карточку партнёра: лепестки у партнёра + пуш.
    func sendSupportPulse(from partner: Partner) {
        backend.sendCarePing(CarePing(type: .sakura, senderId: partner))
        backend.sendInteraction(Interaction(type: .supportPetals, fromPartnerId: partner, createdAt: Date()))
    }

    func sendHugInteraction(from partner: Partner) {
        backend.sendInteraction(Interaction(type: .hug, fromPartnerId: partner, createdAt: Date()))
    }

    /// Скетч — сжатым base64 прямо в документе (как допускает ТЗ).
    func setDailySketch(_ image: UIImage, caption: String, by partner: Partner) {
        guard let base64 = MomentImage.encode(image) else { return }
        backend.setDailyMoment(DailyMoment(type: .sketch, imageBase64: base64, caption: caption,
                                           authorId: partner, updatedAt: Date()))
    }

    /// Фото — в Firebase Storage, в документ кладём imageUrl.
    /// Без Firebase (локальный режим) — сжатым base64, чтобы всё работало и на одном устройстве.
    func setDailyPhoto(_ image: UIImage, caption: String, by partner: Partner,
                       completion: @escaping (Bool) -> Void) {
        guard backend.isCloud else {
            guard let base64 = MomentImage.encode(image) else { completion(false); return }
            backend.setDailyMoment(DailyMoment(type: .photo, imageBase64: base64, caption: caption,
                                               authorId: partner, updatedAt: Date()))
            completion(true)
            return
        }
        guard let jpeg = MomentImage.jpegData(image, maxSide: 1280, quality: 0.75) else { completion(false); return }
        backend.uploadMomentPhoto(jpeg) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    self?.backend.setDailyMoment(DailyMoment(type: .photo, imageBase64: "", imageUrl: url,
                                                             caption: caption, authorId: partner, updatedAt: Date()))
                    completion(true)
                case .failure(let error):
                    print("Photo upload failed:", error.localizedDescription)
                    completion(false)
                }
            }
        }
    }

    /// Вопрос для карточки «Вопрос дня»: сначала тот, на который партнёр уже ответил, а я — нет.
    func homeQuestion(me: Partner) -> (question: QuizQuestion, partnerAnswered: Bool)? {
        let pending = QuestionBank.shared.questions.filter { myAnswer($0, me: me) == nil }
        if let waiting = pending
            .filter({ answers[$0.id]?.answer(for: me.other) != nil })
            .sorted(by: { (answers[$0.id]?.updatedAt ?? .distantPast) > (answers[$1.id]?.updatedAt ?? .distantPast) })
            .first {
            return (waiting, true)
        }
        return questionOfTheDay(me: me).map { ($0, false) }
    }

    // MARK: Hug & care (ТЗ v2, 1.2–1.3)

    func setHugHolding(_ holding: Bool, as partner: Partner, isNewHug: Bool = false) {
        backend.setHugHolding(holding, for: partner, isNewHug: isNewHug)
    }

    func sendCare(_ kind: CarePing.Kind, from partner: Partner) {
        backend.sendCarePing(CarePing(type: kind, senderId: partner))
    }

    /// Непросмотренная поддержка, которую прислали мне.
    func pendingCare(for me: Partner) -> CarePing? {
        carePings
            .filter { !$0.seen && $0.senderId != me }
            .min { $0.createdAt < $1.createdAt }
    }

    func markSeen(_ ping: CarePing) { backend.markCarePingSeen(id: ping.id) }

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

    // MARK: Reactions & comments

    func setReaction(_ emoji: String?, questionId: String, as partner: Partner) {
        backend.setReaction(emoji, questionId: questionId, for: partner)
    }

    func addComment(_ text: String, questionId: String, as partner: Partner) {
        backend.addComment(QuizComment(senderId: partner, text: text, createdAt: Date()), questionId: questionId)
    }

    func deleteComment(_ comment: QuizComment, questionId: String) {
        backend.deleteComment(id: comment.id, questionId: questionId)
    }

    func observeComments(questionId: String, onUpdate: @escaping ([QuizComment]) -> Void) -> Subscription {
        backend.observeComments(questionId: questionId) { comments in
            DispatchQueue.main.async { onUpdate(comments) }
        }
    }

    // MARK: Coupons

    func giveCoupon(title: String, description: String, emoji: String, from partner: Partner) {
        backend.saveCoupon(Coupon(
            title: title, description: description, emoji: emoji,
            createdBy: partner, recipientId: partner.other
        ))
    }

    func markScratched(_ coupon: Coupon) {
        guard !coupon.isScratched else { return }
        var updated = coupon
        updated.isScratched = true
        backend.saveCoupon(updated)
    }

    func redeem(_ coupon: Coupon) {
        guard !coupon.isRedeemed else { return }
        var updated = coupon
        updated.isScratched = true
        updated.isRedeemed = true
        updated.redeemedAt = Date()
        backend.saveCoupon(updated)
    }

    func delete(_ coupon: Coupon) { backend.deleteCoupon(id: coupon.id) }

    func coupons(for partner: Partner) -> [Coupon] {
        coupons.filter { $0.recipientId == partner }.sorted(by: Self.couponOrder)
    }

    func coupons(from partner: Partner) -> [Coupon] {
        coupons.filter { $0.createdBy == partner }.sorted(by: Self.couponOrder)
    }

    /// Сначала неиспользованные, внутри — новые сверху.
    private static func couponOrder(_ a: Coupon, _ b: Coupon) -> Bool {
        if a.isRedeemed != b.isRedeemed { return !a.isRedeemed }
        return a.createdAt > b.createdAt
    }

    // MARK: Guess Mode (ТЗ v2, 3.1)

    static let guessRoundSize = 5

    /// Ключ раунда недели, например «2026-W47».
    static func weekRoundKey(for date: Date = Date()) -> String {
        let cal = Calendar(identifier: .iso8601)
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
    }

    /// 5 вопросов «или/или» на неделю, по кругу из общего банка.
    static func roundQuestions(for date: Date = Date()) -> [QuizQuestion] {
        let pool = QuestionBank.shared.questions.filter { $0.type == .eitherOr }.sorted { $0.id < $1.id }
        guard !pool.isEmpty else { return [] }
        let cal = Calendar(identifier: .iso8601)
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let index = (c.yearForWeekOfYear ?? 0) * 53 + (c.weekOfYear ?? 0)
        let start = (index * guessRoundSize) % pool.count
        return (0..<min(guessRoundSize, pool.count)).map { pool[(start + $0) % pool.count] }
    }

    func guessEntry(roundKey: String, question: QuizQuestion) -> GuessEntry {
        let id = GuessEntry.makeId(roundKey: roundKey, questionId: question.id)
        return guesses[id] ?? GuessEntry(id: id, roundKey: roundKey, questionId: question.id)
    }

    func submitGuess(roundKey: String, question: QuizQuestion, selfAnswer: String, guess: String, as partner: Partner) {
        backend.submitGuess(guessEntry(roundKey: roundKey, question: question),
                            selfAnswer: selfAnswer, guess: guess, for: partner)
    }

    /// Общие звёздочки за все раунды.
    var totalStars: Int {
        guesses.values.reduce(0) { $0 + ($1.starsEarned ?? ($1.isComplete ? $1.computedStars : 0)) }
    }

    /// Когда оба ответили на вопрос, фиксируем звёздочки (одинаково на обоих iPhone).
    private func completeFinishedGuesses() {
        for entry in guesses.values where entry.isComplete && entry.completedAt == nil {
            backend.completeGuess(id: entry.id, stars: entry.computedStars)
        }
    }

    // MARK: Swipe Match

    /// Текущая сессия — самая свежая (активная или уже с совпадением).
    var currentSwipeSession: SwipeSession? {
        swipeSessions.max { $0.createdAt < $1.createdAt }
    }

    var swipeableIdeas: [Idea] {
        ideas.filter { !$0.isScheduled }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func startSwipeSession() {
        backend.createSwipeSession(SwipeSession())
    }

    func vote(_ idea: Idea, like: Bool, in session: SwipeSession, as partner: Partner) {
        backend.voteSwipe(sessionId: session.id, ideaId: idea.id, like: like, for: partner)
    }

    /// Как только оба свайпнули одну идею вправо — фиксируем Match (запись идемпотентна для обоих iPhone).
    private func detectSwipeMatch() {
        guard let session = currentSwipeSession, session.status == .active,
              let ideaId = session.mutualLike else { return }
        backend.setSwipeMatch(sessionId: session.id, ideaId: ideaId)
    }

    func idea(id: String?) -> Idea? {
        guard let id else { return nil }
        return ideas.first { $0.id == id }
    }

    /// Добавить в календарь произвольный план (например, результат колеса фортуны).
    func addPlan(title: String, on date: Date, category: PlanCategory = .special, by partner: Partner) {
        backend.saveEvent(PlanEvent(title: title, date: DayKey.string(date), time: nil,
                                    category: category, note: "", createdBy: partner))
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
