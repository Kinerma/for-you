import Foundation
import WidgetKit

/// Задел под WidgetKit (виджет обратного отсчёта и настроения).
/// Приложение кладёт снимок данных в общий UserDefaults App Group; будущий виджет его читает.
/// Чтобы подключить виджет: File → New → Target → Widget Extension, включить App Group
/// с id ниже у приложения и у виджета, и читать WidgetSnapshot.load().
struct WidgetSnapshot: Codable {
    var nextEventTitle: String?
    var nextEventDate: String?   // YYYY-MM-DD
    var myMoodEmoji: String?
    var partnerMoodEmoji: String?
    var partnerName: String?

    static let appGroupId = "group.com.kinerma.couplespace"
    private static let key = "widget.snapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        if WidgetSnapshot.load().flatMap({ try? JSONEncoder().encode($0) }) == data { return }
        WidgetSnapshot.defaults.set(data, forKey: WidgetSnapshot.key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
