import SwiftUI

/// «Обнять на расстоянии» (ТЗ v2, 1.2).
/// Удерживай кружок: вокруг расходятся акварельные волны, партнёру летит пуш.
/// Если держите оба — тёплое свечение и синхронное сердцебиение на обоих iPhone.
struct HugCard: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.scenePhase) private var scenePhase

    @State private var pressing = false      // палец на кнопке
    @State private var holding = false       // удержание засчитано (после короткой задержки)
    @State private var holdStart: Date?
    @State private var pressTask: Task<Void, Never>?

    private var me: Partner { session.me }
    private var partnerName: String { store.partnerName(me.other) ?? loc.t(.partner) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let partnerHolding = store.hug.isHolding(me.other, now: timeline.date)
            let together = holding && partnerHolding

            VStack(spacing: 14) {
                HStack {
                    CardLabel(text: loc.t(.hugTitle), symbol: "hands.and.sparkles.fill")
                    Spacer()
                }

                hugButton(together: together)
                    .frame(height: 190)

                Text(caption(partnerHolding: partnerHolding, together: together))
                    .font(.appSubheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(together ? Palette.rose : Palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut, value: together)
            }
            .glassCard()
            .background {
                if together {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [Palette.rose.opacity(0.55), Palette.champagne],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .blur(radius: 22)
                        .padding(-14)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.8), value: together)
            .onChange(of: together) { _, isTogether in
                if isTogether { HeartbeatHaptics.shared.start() } else { HeartbeatHaptics.shared.stop() }
            }
        }
        // Пока держим — продлеваем «присутствие» каждые 5 секунд (иначе через 15 сек оно истечёт).
        .task(id: holding) {
            guard holding else { return }
            while !Task.isCancelled && holding {
                try? await Task.sleep(for: .seconds(5))
                guard holding, !Task.isCancelled else { break }
                store.setHugHolding(true, as: me)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { release() }
        }
        .onDisappear { release() }
    }

    // MARK: Button

    private func hugButton(together: Bool) -> some View {
        ZStack {
            if holding {
                TimelineView(.animation) { timeline in
                    Canvas { ctx, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let t = timeline.date.timeIntervalSince(holdStart ?? timeline.date)
                        for i in 0..<4 {
                            let phase = (t / 2.4 + Double(i) / 4).truncatingRemainder(dividingBy: 1)
                            let r = 52 + phase * 48
                            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                            let color = i.isMultiple(of: 2) ? Palette.rose : Palette.lavenderDeep
                            ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.22 * (1 - phase))))
                        }
                    }
                    .blur(radius: 6)
                }
                .transition(.opacity)
            }

            Circle()
                .fill(together ? AnyShapeStyle(LinearGradient(colors: [Palette.rose, Color(hex: 0xF6B27A)], startPoint: .top, endPoint: .bottom))
                               : AnyShapeStyle(Palette.accentGradient))
                .frame(width: 108, height: 108)
                .overlay {
                    Image(systemName: together ? "heart.fill" : "hand.raised.fingers.spread.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: holding)
                }
                .shadow(color: Palette.rose.opacity(0.4), radius: pressing ? 22 : 12, y: 6)
                .scaleEffect(pressing ? 0.94 : 1)
                .animation(.spring(duration: 0.3), value: pressing)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in press() }
                        .onEnded { _ in release() }
                )
                .accessibilityLabel(loc.t(.hugTitle))
                .accessibilityHint(loc.t(.hugHint))
        }
    }

    private func caption(partnerHolding: Bool, together: Bool) -> String {
        if together { return loc.t(.hugTogether) }
        if partnerHolding { return "\(partnerName) \(loc.t(.hugPartnerHolding))" }
        if holding { return loc.t(.hugSending) }
        return loc.t(.hugHint)
    }

    // MARK: Press handling

    private func press() {
        guard !pressing else { return }
        pressing = true
        pressTask = Task { @MainActor in
            // Короткая задержка, чтобы случайное касание не отправляло объятие.
            try? await Task.sleep(for: .milliseconds(350))
            guard pressing, !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                holding = true
                holdStart = Date()
            }
            HeartbeatHaptics.shared.softTap()
            store.setHugHolding(true, as: me, isNewHug: true)
        }
    }

    private func release() {
        pressTask?.cancel()
        pressTask = nil
        pressing = false
        guard holding else { return }
        withAnimation(.easeOut(duration: 0.4)) { holding = false }
        holdStart = nil
        HeartbeatHaptics.shared.stop()
        store.setHugHolding(false, as: me)
    }
}
