import Foundation

enum RoomUpdate {
    case meta(RoomMeta)
    case moods([Partner: Mood])
    case answers([String: QuizAnswer])
    case events([PlanEvent])
    case ideas([Idea])
}

/// Источник данных общей комнаты. Firestore — когда в проекте есть GoogleService-Info.plist,
/// иначе локальный режим на одном устройстве (удобно для разработки и превью).
protocol RoomBackend: AnyObject {
    var isCloud: Bool { get }

    func connect(roomId: String, onUpdate: @escaping (RoomUpdate) -> Void)
    func disconnect()

    func createRoom()
    func setProfile(name: String, language: AppLanguage, for partner: Partner)
    func setMood(_ mood: Mood, for partner: Partner)
    func setAnswer(_ value: String, question: QuizQuestion, for partner: Partner)
    func saveEvent(_ event: PlanEvent)
    func deleteEvent(id: String)
    func saveIdea(_ idea: Idea)
    func deleteIdea(id: String)
}
