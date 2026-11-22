import SwiftUI

@main
struct CoupleSpaceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var localization: LocalizationManager
    @State private var session: AppSession
    @State private var store: RoomStore

    init() {
        // Firebase должен быть настроен до создания RoomStore.
        FirebaseBootstrap.configureIfPossible()
        _localization = State(initialValue: LocalizationManager())
        _session = State(initialValue: AppSession())
        _store = State(initialValue: RoomStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(localization)
                .environment(session)
                .environment(store)
                .tint(Palette.rose)
                .preferredColorScheme(.light)
        }
    }
}
