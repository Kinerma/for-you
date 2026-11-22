import SwiftUI

/// «Тиндер» для идей из Копилки (ТЗ v2, 2.1).
struct SwipeMatchView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var dragOffset: CGSize = .zero
    @State private var flyingAway: (id: String, like: Bool)?
    @State private var voteTrigger = 0
    @State private var matchTrigger = 0
    @State private var pickingDate = false
    @State private var planDate = Date()
    @State private var addedToCalendar = false

    private var me: Partner { session.me }
    private var current: SwipeSession? { store.currentSwipeSession }

    /// Карточки, за которые я ещё не голосовал(а) в этой сессии.
    private var deck: [Idea] {
        guard let current else { return [] }
        let voted = current.votes(for: me)
        return store.swipeableIdeas.filter { voted[$0.id] == nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WatercolorBackground()
                content
                    .padding(20)
                if current?.status == .matched {
                    ParticleRain(kind: .confetti)
                        .id(current?.id)
                }
            }
            .navigationTitle(loc.t(.swipeTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.done)) { dismiss() }.fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: voteTrigger)
            .sensoryFeedback(.success, trigger: matchTrigger)
            .onChange(of: current?.status) { old, new in
                if new == .matched && old == .active { matchTrigger += 1 }
            }
        }
        .onAppear {
            if current == nil && store.swipeableIdeas.count >= 2 { store.startSwipeSession() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.swipeableIdeas.count < 2 && current?.status != .matched {
            message(icon: "sparkles.rectangle.stack", text: loc.t(.swipeNeedIdeas))
        } else if let current, current.status == .matched {
            matchScreen(current)
        } else if current == nil {
            ProgressView()
        } else if deck.isEmpty {
            VStack(spacing: 18) {
                message(icon: "hourglass", text: loc.t(.swipeWaiting))
                Button(loc.t(.swipeNewRound)) { store.startSwipeSession() }
                    .buttonStyle(SoftButtonStyle())
            }
        } else {
            deckScreen
        }
    }

    // MARK: Deck

    private var deckScreen: some View {
        VStack(spacing: 22) {
            ZStack {
                ForEach(Array(deck.prefix(3).enumerated().reversed()), id: \.element.id) { index, idea in
                    let isTop = index == 0
                    IdeaSwipeCard(idea: idea, likeAmount: isTop ? dragOffset.width / 120 : 0)
                        .scaleEffect(1 - CGFloat(index) * 0.05)
                        .offset(y: CGFloat(index) * 14)
                        .offset(isTop ? dragOffset : .zero)
                        .rotationEffect(.degrees(isTop ? Double(dragOffset.width / 18) : 0))
                        .allowsHitTesting(isTop)
                        .gesture(dragGesture(for: idea))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)

            HStack(spacing: 40) {
                roundButton(symbol: "xmark", color: Palette.inkSoft) { if let top = deck.first { swipe(top, like: false) } }
                    .accessibilityLabel(loc.t(.swipeLater))
                roundButton(symbol: "heart.fill", color: Palette.rose) { if let top = deck.first { swipe(top, like: true) } }
                    .accessibilityLabel(loc.t(.swipeYes))
            }
            Spacer(minLength: 0)
        }
    }

    private func dragGesture(for idea: Idea) -> some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                if value.translation.width > 110 {
                    swipe(idea, like: true)
                } else if value.translation.width < -110 {
                    swipe(idea, like: false)
                } else {
                    withAnimation(.spring(duration: 0.35)) { dragOffset = .zero }
                }
            }
    }

    private func swipe(_ idea: Idea, like: Bool) {
        guard let current, flyingAway == nil else { return }
        voteTrigger += 1
        withAnimation(.easeIn(duration: 0.25)) {
            dragOffset = CGSize(width: like ? 600 : -600, height: dragOffset.height + 40)
        }
        flyingAway = (idea.id, like)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            store.vote(idea, like: like, in: current, as: me)
            flyingAway = nil
            dragOffset = .zero
        }
    }

    private func roundButton(symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 68, height: 68)
                .background(Color.white.opacity(0.85), in: Circle())
                .shadow(color: Palette.rose.opacity(0.2), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: Match

    @ViewBuilder
    private func matchScreen(_ session: SwipeSession) -> some View {
        let idea = store.idea(id: session.matchedIdeaId)
        VStack(spacing: 18) {
            Spacer()
            Text(loc.t(.match))
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.accentGradient)
            Text(loc.t(.matchSubtitle))
                .font(.appBody)
                .foregroundStyle(Palette.inkSoft)
            if let idea {
                IdeaSwipeCard(idea: idea, likeAmount: 0)
                    .frame(height: 260)
            }

            if addedToCalendar {
                Label(loc.t(.addedToCalendar), systemImage: "checkmark.circle.fill")
                    .font(.appBody.weight(.semibold))
                    .foregroundStyle(Palette.walk)
            } else if let idea {
                if pickingDate {
                    DatePicker(loc.t(.planDate), selection: $planDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, loc.locale)
                        .glassCard(padding: 12)
                    Button(loc.t(.toCalendar)) { schedule(idea, on: planDate) }
                        .buttonStyle(GradientButtonStyle())
                } else {
                    Button(loc.t(.addToday)) { schedule(idea, on: Date()) }
                        .buttonStyle(GradientButtonStyle())
                    Button(loc.t(.chooseDate)) { withAnimation { pickingDate = true } }
                        .buttonStyle(SoftButtonStyle())
                }
            }

            Button(loc.t(.swipeNewRound)) {
                addedToCalendar = false
                pickingDate = false
                store.startSwipeSession()
            }
            .buttonStyle(SoftButtonStyle())
            Spacer()
        }
    }

    private func schedule(_ idea: Idea, on date: Date) {
        store.schedule(idea, on: date, by: me)
        withAnimation { addedToCalendar = true }
    }

    private func message(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Palette.accentGradient)
            Text(text)
                .font(.appBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 28)
    }
}

/// Карточка идеи со штампами «Да» / «Позже», проявляющимися при наклоне.
struct IdeaSwipeCard: View {
    let idea: Idea
    /// −1…1: насколько карточку утянули влево/вправо.
    let likeAmount: CGFloat

    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color.white, idea.category.color.opacity(0.35)],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)

            VStack(spacing: 14) {
                Image(systemName: idea.category.symbol)
                    .font(.system(size: 34))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(idea.category.color, in: Circle())
                Text(idea.title)
                    .font(.appTitle(loc.language, size: 26))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink)
                Text(loc.t(idea.category.titleKey))
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(idea.category.color)
                if !idea.note.isEmpty {
                    Text(idea.note)
                        .font(.appBody)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(4)
                }
            }
            .padding(26)

            VStack {
                HStack {
                    stamp(loc.t(.swipeYes), color: Palette.walk)
                        .rotationEffect(.degrees(-14))
                        .opacity(Double(max(0, likeAmount)))
                    Spacer()
                    stamp(loc.t(.swipeLater), color: Palette.inkSoft)
                        .rotationEffect(.degrees(14))
                        .opacity(Double(max(0, -likeAmount)))
                }
                Spacer()
            }
            .padding(22)
        }
        .shadow(color: Palette.rose.opacity(0.22), radius: 18, y: 10)
    }

    private func stamp(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 3))
    }
}
