import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            WatercolorBackground()

            if session.isOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }

            if session.isOnboarded && session.isLocked {
                LockScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.isLocked)
        .animation(.easeInOut(duration: 0.35), value: session.isOnboarded)
        .foregroundStyle(Palette.ink)
        .task(id: session.roomId) {
            guard session.isOnboarded else { return }
            store.connect(roomId: session.roomId)
            PushManager.requestPermissionAndRegister()
            PushManager.subscribe(roomId: session.roomId, partner: session.me)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { session.lock() }
        }
        .onChange(of: store.nextEvent) { _, _ in store.updateWidgetSnapshot(me: session.me) }
        .onChange(of: store.moods) { _, _ in store.updateWidgetSnapshot(me: session.me) }
        .onChange(of: loc.language) { _, newValue in
            // Язык нужен Cloud Function, чтобы прислать пуш на правильном языке.
            guard session.isOnboarded else { return }
            store.setProfile(name: session.name, language: newValue, for: session.me)
        }
    }
}

struct MainTabView: View {
    @Environment(AppSession.self) private var session
    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        @Bindable var session = session
        TabView(selection: $session.selectedTab) {
            HomeView()
                .tabItem { Label(loc.t(.tabHome), systemImage: "house.fill") }
                .tag(AppTab.home)
            QuizView()
                .tabItem { Label(loc.t(.tabQuiz), systemImage: "heart.text.square.fill") }
                .tag(AppTab.quiz)
            CalendarView()
                .tabItem { Label(loc.t(.tabCalendar), systemImage: "calendar") }
                .tag(AppTab.calendar)
        }
        .sheet(isPresented: $session.showSettings) {
            SettingsSheet()
        }
    }
}
