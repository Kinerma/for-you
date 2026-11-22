import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// Firebase включается только если в бандле есть GoogleService-Info.plist —
/// без него приложение работает в локальном режиме и не падает.
enum FirebaseBootstrap {
    private(set) static var isConfigured = false

    static func configureIfPossible() {
        guard !isConfigured,
              Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        else { return }
        FirebaseApp.configure()
        isConfigured = true
    }
}

/// Push-уведомления (FCM). Каждый партнёр подписан на свой топик room_{roomId}_{A|B};
/// Cloud Function (functions/index.js) шлёт уведомление в топик второго партнёра.
enum PushManager {
    static func topic(roomId: String, partner: Partner) -> String {
        "room_\(roomId)_\(partner.rawValue)"
    }

    static func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    static func subscribe(roomId: String, partner: Partner) {
        guard FirebaseBootstrap.isConfigured else { return }
        Messaging.messaging().subscribe(toTopic: topic(roomId: roomId, partner: partner))
    }

    static func unsubscribe(roomId: String, partner: Partner) {
        guard FirebaseBootstrap.isConfigured else { return }
        Messaging.messaging().unsubscribe(fromTopic: topic(roomId: roomId, partner: partner))
    }
}
