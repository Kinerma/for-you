import SwiftUI
import UIKit

/// Колесо фортуны с тактильным щелчком на каждой границе сектора (ТЗ v2, 2.2).
struct WheelOfFortuneView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    struct Option: Identifiable, Hashable {
        var id = UUID()
        var title: String
        var idea: Idea?
    }

    @State private var options: [Option] = []
    @State private var newOption = ""

    // Вращение считаем сами по времени, чтобы точно ловить каждую границу сектора.
    @State private var angle: Double = 0            // градусы, по часовой
    @State private var spinFrom: Double = 0
    @State private var spinTo: Double = 0
    @State private var spinStart: Date?
    @State private var lastSector: Int?
    @State private var result: Option?
    @State private var added = false

    private let spinDuration: Double = 4.6
    @State private var tick = UIImpactFeedbackGenerator(style: .light)
    @State private var finish = UINotificationFeedbackGenerator()

    private var spinning: Bool { spinStart != nil }
    private var canSpin: Bool { (2...8).contains(options.count) && !spinning }
    private var sectorSize: Double { 360 / Double(max(options.count, 1)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    wheel
                        .frame(width: 300, height: 320)

                    if let result, !spinning {
                        resultCard(result)
                    }

                    Button(loc.t(.wheelSpin), action: spin)
                        .buttonStyle(GradientButtonStyle())
                        .disabled(!canSpin)

                    optionsEditor
                }
                .padding(20)
            }
            .background(WatercolorBackground())
            .navigationTitle(loc.t(.wheelTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.done)) { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .onAppear(perform: loadFromJar)
    }

    // MARK: Wheel

    private var wheel: some View {
        TimelineView(.animation(paused: !spinning)) { timeline in
            let current = currentAngle(at: timeline.date)
            ZStack(alignment: .top) {
                WheelCanvas(titles: options.map(\.title), lang: loc.language)
                    .rotationEffect(.degrees(current))
                    .frame(width: 300, height: 300)
                    .padding(.top, 20)
                    .shadow(color: Palette.rose.opacity(0.25), radius: 18, y: 8)

                // Стрелка сверху
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Palette.accentGradient)
                    .shadow(color: .white, radius: 2)

                Circle()
                    .fill(Color.white)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "heart.fill").foregroundStyle(Palette.rose))
                    .shadow(color: Palette.rose.opacity(0.3), radius: 6)
                    .padding(.top, 20 + 150 - 22)
            }
            .onChange(of: sectorIndex(for: current)) { _, newSector in
                guard spinning else { return }
                if lastSector != newSector {
                    lastSector = newSector
                    tick.impactOccurred()
                }
            }
            .onChange(of: timeline.date) { _, date in
                if let spinStart, date.timeIntervalSince(spinStart) >= spinDuration {
                    stopSpin()
                }
            }
        }
    }

    private func currentAngle(at date: Date) -> Double {
        guard let spinStart else { return angle }
        let t = min(1, max(0, date.timeIntervalSince(spinStart) / spinDuration))
        let eased = 1 - pow(1 - t, 4)   // плавное замедление
        return spinFrom + (spinTo - spinFrom) * eased
    }

    /// Какой сектор сейчас под стрелкой. Сектор 0 начинается сверху и идёт по часовой.
    private func sectorIndex(for rotation: Double) -> Int {
        guard !options.isEmpty else { return 0 }
        let normalized = ((-rotation).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return min(options.count - 1, Int(normalized / sectorSize))
    }

    private func spin() {
        guard canSpin else { return }
        result = nil
        added = false
        tick.prepare()
        finish.prepare()
        spinFrom = angle
        spinTo = angle + Double(Int.random(in: 4...6)) * 360 + Double.random(in: 0..<360)
        lastSector = sectorIndex(for: angle)
        spinStart = Date()
    }

    private func stopSpin() {
        angle = spinTo.truncatingRemainder(dividingBy: 360)
        spinStart = nil
        finish.notificationOccurred(.success)
        let index = sectorIndex(for: angle)
        if options.indices.contains(index) {
            withAnimation(.spring(duration: 0.4)) { result = options[index] }
        }
    }

    // MARK: Result

    private func resultCard(_ option: Option) -> some View {
        VStack(spacing: 12) {
            Text(loc.t(.wheelResult))
                .font(.appSubheadline)
                .foregroundStyle(Palette.inkSoft)
            Text(option.title)
                .font(.appTitle(loc.language, size: 26))
                .multilineTextAlignment(.center)
            if added {
                Label(loc.t(.addedToCalendar), systemImage: "checkmark.circle.fill")
                    .font(.appBody.weight(.semibold))
                    .foregroundStyle(Palette.walk)
            } else {
                Button(loc.t(.addToday)) {
                    if let idea = option.idea {
                        store.schedule(idea, on: Date(), by: session.me)
                    } else {
                        store.addPlan(title: option.title, on: Date(), by: session.me)
                    }
                    withAnimation { added = true }
                }
                .buttonStyle(SoftButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: Options

    private var optionsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardLabel(text: loc.t(.wheelOptions), symbol: "list.bullet")
                Spacer()
                Button(loc.t(.wheelFromJar), action: loadFromJar)
                    .buttonStyle(SoftButtonStyle())
                    .disabled(spinning || store.swipeableIdeas.isEmpty)
            }
            ForEach(options) { option in
                HStack {
                    Circle().fill(WheelCanvas.color(at: options.firstIndex(of: option) ?? 0)).frame(width: 12, height: 12)
                    Text(option.title).font(.appBody).lineLimit(1)
                    Spacer()
                    Button {
                        options.removeAll { $0.id == option.id }
                        result = nil
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(Palette.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .disabled(spinning)
                }
                .padding(.vertical, 4)
            }
            if options.count < 8 {
                HStack(spacing: 8) {
                    SoftField(placeholder: loc.t(.wheelOptionPlaceholder), text: $newOption)
                        .onSubmit(addOption)
                    Button(action: addOption) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Palette.accentGradient, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(newOption.trimmingCharacters(in: .whitespaces).isEmpty || spinning)
                }
            }
            if !(2...8).contains(options.count) {
                Text(loc.t(.wheelNeedOptions))
                    .font(.appCaption)
                    .foregroundStyle(Palette.rose)
            }
        }
        .glassCard()
    }

    private func addOption() {
        let title = newOption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, options.count < 8 else { return }
        options.append(Option(title: title))
        newOption = ""
        result = nil
    }

    private func loadFromJar() {
        guard !spinning else { return }
        options = store.swipeableIdeas.shuffled().prefix(8).map { Option(title: $0.title, idea: $0) }
        result = nil
    }
}

/// Пастельные секторы с подписями.
struct WheelCanvas: View {
    let titles: [String]
    let lang: AppLanguage

    static let palette: [Color] = [
        Palette.sakura, Palette.lavender, Palette.champagne,
        Color(hex: 0xCFE3DE), Color(hex: 0xF5CFC9), Color(hex: 0xE9D3EC),
        Color(hex: 0xFBE3C4), Color(hex: 0xD9E4F5),
    ]

    static func color(at index: Int) -> Color { palette[index % palette.count] }

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let count = max(titles.count, 1)
            let sweep = 360.0 / Double(count)

            for i in 0..<count {
                // Сектор 0 начинается сверху (−90°) и идёт по часовой.
                let start = Angle.degrees(-90 + Double(i) * sweep)
                let end = Angle.degrees(-90 + Double(i + 1) * sweep)
                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                path.closeSubpath()
                ctx.fill(path, with: .color(titles.isEmpty ? Palette.sakura : Self.color(at: i)))
                ctx.stroke(path, with: .color(.white), lineWidth: 2)

                guard i < titles.count else { continue }
                let mid = -90 + (Double(i) + 0.5) * sweep
                var label = ctx
                label.translateBy(x: center.x, y: center.y)
                label.rotate(by: .degrees(mid))
                let text = titles[i].count > 16 ? String(titles[i].prefix(15)) + "…" : titles[i]
                label.draw(
                    Text(text)
                        .font(lang == .zhHant ? .custom("PingFangTC-Semibold", size: 13) : .system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.ink),
                    at: CGPoint(x: radius * 0.58, y: 0)
                )
            }
            ctx.stroke(Path(ellipseIn: CGRect(x: center.x - radius + 1, y: center.y - radius + 1,
                                              width: radius * 2 - 2, height: radius * 2 - 2)),
                       with: .color(.white), lineWidth: 4)
        }
    }
}
