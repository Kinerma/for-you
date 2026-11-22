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

            if session.isOnboarded && !session.isLocked, let ping = store.pendingCare(for: session.me) {
                CareOverlay(ping: ping)
                    .id(ping.id)
                    .zIndex(2)
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
        .onChange(of: store.meta.pinHash) { _, newHash in
            // PIN общий: при входе по коду и при смене PIN партнёром подтягиваем его хеш.
            guard let newHash, !newHash.isEmpty, newHash != PinStore.currentHash else { return }
            PinStore.saveHash(newHash)
        }
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
            SurprisesView()
                .tabItem { Label(loc.t(.tabSurprises), systemImage: "gift.fill") }
                .tag(AppTab.surprises)
        }
        .sheet(isPresented: $session.showSettings) {
            SettingsSheet()
        }
    }
}

/// Полученная поддержка: лепестки сакуры / сердечки / искорки на весь экран (ТЗ v2, 1.3).
struct CareOverlay: View {
    let ping: CarePing

    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    @State private var visible = false
    @State private var trigger = 0

    private var kind: ParticleRain.Kind {
        switch ping.type {
        case .sakura: return .petals
        case .hearts: return .hearts
        case .hugSparkle: return .sparkles
        }
    }

    var body: some View {
        ZStack {
            ParticleRain(kind: kind, count: 60, duration: 3.4)

            if visible {
                VStack(spacing: 6) {
                    Text(ping.emoji).font(.system(size: 44))
                    Text("\(store.partnerName(ping.senderId) ?? loc.t(.partner)) \(loc.t(.careReceived))")
                        .font(.appBody.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.ink)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .sensoryFeedback(.impact(weight: .light), trigger: trigger)
        .task {
            withAnimation(.spring(duration: 0.5)) { visible = true }
            trigger += 1
            try? await Task.sleep(for: .seconds(3.2))
            withAnimation(.easeOut(duration: 0.5)) { visible = false }
            try? await Task.sleep(for: .seconds(0.6))
            store.markSeen(ping)
        }
    }
}
