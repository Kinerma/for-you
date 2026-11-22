import SwiftUI
import Observation

enum AppTab: Hashable {
    case home, quiz, calendar
}

/// Профиль на этом устройстве: роль, имя, комната, блокировка и навигация.
@Observable
final class AppSession {
    private enum Keys {
        static let role = "session.role"
        static let name = "session.name"
        static let roomId = "session.roomId"
        static let faceID = "session.faceID"
    }

    var role: Partner? {
        didSet { UserDefaults.standard.set(role?.rawValue, forKey: Keys.role) }
    }
    var name: String {
        didSet { UserDefaults.standard.set(name, forKey: Keys.name) }
    }
    var roomId: String {
        didSet { UserDefaults.standard.set(roomId, forKey: Keys.roomId) }
    }
    var faceIDEnabled: Bool {
        didSet { UserDefaults.standard.set(faceIDEnabled, forKey: Keys.faceID) }
    }

    var isLocked = true
    var selectedTab: AppTab = .home
    var focusedQuestionId: String?
    var showSettings = false

    init() {
        let d = UserDefaults.standard
        role = d.string(forKey: Keys.role).flatMap(Partner.init(rawValue:))
        name = d.string(forKey: Keys.name) ?? ""
        roomId = d.string(forKey: Keys.roomId) ?? ""
        faceIDEnabled = d.object(forKey: Keys.faceID) as? Bool ?? true
        isLocked = PinStore.hasPin
    }

    var isOnboarded: Bool { role != nil && !roomId.isEmpty }

    /// Роль гарантированно есть после онбординга.
    var me: Partner { role ?? .a }

    func completeOnboarding(role: Partner, name: String, roomId: String) {
        self.role = role
        self.name = name
        self.roomId = roomId
        isLocked = false
    }

    func leaveRoom() {
        roomId = ""
        role = nil
        selectedTab = .home
    }

    // MARK: Lock

    func lock() {
        guard isOnboarded, PinStore.hasPin else { return }
        isLocked = true
    }

    @discardableResult
    func unlock(pin: String) -> Bool {
        guard pin == PinStore.current else { return false }
        isLocked = false
        return true
    }

    func unlockWithBiometrics(reason: String) async {
        guard faceIDEnabled, Biometrics.isAvailable else { return }
        if await Biometrics.authenticate(reason: reason) {
            await MainActor.run { self.isLocked = false }
        }
    }

    static func generateRoomCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }
}
