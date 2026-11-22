import Foundation

/// Локальный режим без Firebase: данные одной комнаты хранятся в файле на устройстве.
final class LocalBackend: RoomBackend {
    let isCloud = false

    private struct State: Codable {
        var meta = RoomMeta()
        var moods: [String: Mood] = [:]
        var answers: [String: QuizAnswer] = [:]
        var events: [String: PlanEvent] = [:]
        var ideas: [String: Idea] = [:]
        var coupons: [String: Coupon] = [:]
        var comments: [String: [QuizComment]] = [:]
        var swipeSessions: [String: SwipeSession] = [:]
    }

    private var state = State()
    private var roomId: String?
    private var onUpdate: ((RoomUpdate) -> Void)?
    private var commentObservers: [String: [UUID: ([QuizComment]) -> Void]] = [:]

    func connect(roomId: String, onUpdate: @escaping (RoomUpdate) -> Void) {
        self.roomId = roomId
        self.onUpdate = onUpdate
        state = load(roomId) ?? State()
        emitAll()
    }

    func disconnect() {
        roomId = nil
        onUpdate = nil
    }

    func createRoom() {
        if state.meta.createdAt == nil { state.meta.createdAt = Date() }
        commit()
    }

    func setProfile(name: String, language: AppLanguage, for partner: Partner) {
        switch partner {
        case .a: state.meta.partnerAName = name; state.meta.langA = language.rawValue
        case .b: state.meta.partnerBName = name; state.meta.langB = language.rawValue
        }
        commit()
    }

    func setPinHash(_ hash: String) {
        state.meta.pinHash = hash
        commit()
    }

    func setMood(_ mood: Mood, for partner: Partner) {
        state.moods[partner.rawValue] = mood
        commit()
    }

    func setAnswer(_ value: String, question: QuizQuestion, for partner: Partner) {
        var answer = state.answers[question.id] ?? QuizAnswer(
            questionId: question.id, category: question.category, type: question.type.rawValue,
            answerA: nil, answerB: nil, updatedAt: Date()
        )
        switch partner {
        case .a: answer.answerA = value
        case .b: answer.answerB = value
        }
        answer.updatedAt = Date()
        state.answers[question.id] = answer
        commit()
    }

    func saveEvent(_ event: PlanEvent) { state.events[event.id] = event; commit() }
    func deleteEvent(id: String) { state.events[id] = nil; commit() }
    func saveIdea(_ idea: Idea) { state.ideas[idea.id] = idea; commit() }
    func deleteIdea(id: String) { state.ideas[id] = nil; commit() }

    func setReaction(_ emoji: String?, questionId: String, for partner: Partner) {
        guard var answer = state.answers[questionId] else { return }
        switch partner {
        case .a: answer.reactionA = emoji
        case .b: answer.reactionB = emoji
        }
        state.answers[questionId] = answer
        commit()
    }

    func addComment(_ comment: QuizComment, questionId: String) {
        state.comments[questionId, default: []].append(comment)
        commit()
        notifyComments(questionId)
    }

    func deleteComment(id: String, questionId: String) {
        state.comments[questionId]?.removeAll { $0.id == id }
        commit()
        notifyComments(questionId)
    }

    func observeComments(questionId: String, onUpdate: @escaping ([QuizComment]) -> Void) -> Subscription {
        let token = UUID()
        commentObservers[questionId, default: [:]][token] = onUpdate
        onUpdate(state.comments[questionId] ?? [])
        return Subscription { [weak self] in
            self?.commentObservers[questionId]?[token] = nil
        }
    }

    private func notifyComments(_ questionId: String) {
        let list = state.comments[questionId] ?? []
        commentObservers[questionId]?.values.forEach { $0(list) }
    }

    func saveCoupon(_ coupon: Coupon) { state.coupons[coupon.id] = coupon; commit() }
    func deleteCoupon(id: String) { state.coupons[id] = nil; commit() }

    func createSwipeSession(_ session: SwipeSession) {
        state.swipeSessions[session.id] = session
        commit()
    }

    func voteSwipe(sessionId: String, ideaId: String, like: Bool, for partner: Partner) {
        guard var session = state.swipeSessions[sessionId] else { return }
        switch partner {
        case .a: session.votesA[ideaId] = like
        case .b: session.votesB[ideaId] = like
        }
        state.swipeSessions[sessionId] = session
        commit()
    }

    func setSwipeMatch(sessionId: String, ideaId: String) {
        guard var session = state.swipeSessions[sessionId] else { return }
        session.status = .matched
        session.matchedIdeaId = ideaId
        state.swipeSessions[sessionId] = session
        commit()
    }

    // MARK: Private

    private func commit() {
        if let roomId { save(state, roomId) }
        emitAll()
    }

    private func emitAll() {
        guard let onUpdate else { return }
        var moods: [Partner: Mood] = [:]
        for (key, mood) in state.moods {
            if let partner = Partner(rawValue: key) { moods[partner] = mood }
        }
        onUpdate(.meta(state.meta))
        onUpdate(.moods(moods))
        onUpdate(.answers(state.answers))
        onUpdate(.events(Array(state.events.values)))
        onUpdate(.ideas(Array(state.ideas.values)))
        onUpdate(.coupons(Array(state.coupons.values)))
        onUpdate(.swipeSessions(Array(state.swipeSessions.values)))
    }

    private func fileURL(_ roomId: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("room-\(roomId).json")
    }

    private func load(_ roomId: String) -> State? {
        guard let data = try? Data(contentsOf: fileURL(roomId)) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    private func save(_ state: State, _ roomId: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL(roomId), options: .atomic)
    }
}
