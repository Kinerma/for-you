import Foundation

enum RoomUpdate {
    case meta(RoomMeta)
    case moods([Partner: Mood])
    case answers([String: QuizAnswer])
    case events([PlanEvent])
    case ideas([Idea])
    case coupons([Coupon])
    case swipeSessions([SwipeSession])
    case hug(HugPresence)
    case carePings([CarePing])
    case guesses([GuessEntry])
    case interaction(Interaction?)
    case dailyMoment(DailyMoment?)
}

/// Отписка от слушателя (например, комментариев одной карточки).
final class Subscription {
    private var cancel: (() -> Void)?
    init(_ cancel: @escaping () -> Void) { self.cancel = cancel }
    func cancelNow() { cancel?(); cancel = nil }
    deinit { cancel?() }
}

/// Источник данных общей комнаты. Firestore — когда в проекте есть GoogleService-Info.plist,
/// иначе локальный режим на одном устройстве (удобно для разработки и превью).
protocol RoomBackend: AnyObject {
    var isCloud: Bool { get }

    func connect(roomId: String, onUpdate: @escaping (RoomUpdate) -> Void)
    func disconnect()

    func createRoom()
    func setProfile(name: String, language: AppLanguage, for partner: Partner)
    func setPinHash(_ hash: String)
    func setMood(_ mood: Mood, for partner: Partner)
    func setAnswer(_ value: String, question: QuizQuestion, for partner: Partner)
    func saveEvent(_ event: PlanEvent)
    func deleteEvent(id: String)
    func saveIdea(_ idea: Idea)
    func deleteIdea(id: String)

    // Реакции и комментарии к ответам
    func setReaction(_ emoji: String?, questionId: String, for partner: Partner)
    func addComment(_ comment: QuizComment, questionId: String)
    func deleteComment(id: String, questionId: String)
    func observeComments(questionId: String, onUpdate: @escaping ([QuizComment]) -> Void) -> Subscription

    // Купоны
    func saveCoupon(_ coupon: Coupon)
    func deleteCoupon(id: String)

    // Свайпы
    func createSwipeSession(_ session: SwipeSession)
    func voteSwipe(sessionId: String, ideaId: String, like: Bool, for partner: Partner)
    func setSwipeMatch(sessionId: String, ideaId: String)

    // Объятия и поддержка
    func setHugHolding(_ holding: Bool, for partner: Partner, isNewHug: Bool)
    func sendCarePing(_ ping: CarePing)
    func markCarePingSeen(id: String)

    // Угадайка
    func submitGuess(_ entry: GuessEntry, selfAnswer: String, guess: String, for partner: Partner)
    func completeGuess(id: String, stars: Int)

    // Главная
    func setRelationshipStart(_ date: Date)
    func sendInteraction(_ interaction: Interaction)
    func setDailyMoment(_ moment: DailyMoment)
}
