import Foundation
import CryptoKit
import LocalAuthentication
import Security

/// PIN-код общий для комнаты: его задаёт тот, кто создаёт комнату.
/// В Keychain и в Firestore (rooms/{roomId}.meta.pinHash) хранится только хеш, сам код — нигде.
enum PinStore {
    private static let service = "com.kinerma.couplespace"
    private static let account = "pinHash"

    static func hash(_ pin: String, roomId: String) -> String {
        let digest = SHA256.hash(data: Data("couplespace:\(roomId):\(pin)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static var currentHash: String? { read() }
    static var hasPin: Bool { !(read() ?? "").isEmpty }

    static func verify(_ pin: String, roomId: String) -> Bool {
        guard let stored = read(), !stored.isEmpty else { return false }
        return stored == hash(pin, roomId: roomId)
    }

    static func saveHash(_ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

enum Biometrics {
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    }
}
