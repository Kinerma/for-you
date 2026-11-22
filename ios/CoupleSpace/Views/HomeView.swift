import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    @State private var editingMood = false
    @State private var careSent = 0

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let key: L = hour < 12 ? .goodMorning : (hour < 18 ? .goodAfternoon : .goodEvening)
        return loc.t(key)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TopBar(subtitle: greeting, title: session.name.isEmpty ? loc.t(.onbTitle) : session.name)
                CountdownCard()
                moodSection
                HugCard()
                QuestionOfDayCard()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(WatercolorBackground())
        .sheet(isPresented: $editingMood) {
            MoodSheet(current: store.moods[session.me])
                .presentationDetents([.medium, .large])
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardLabel(text: loc.t(.moodTitle), symbol: "face.smiling")
            HStack(spacing: 12) {
                Button { editingMood = true } label: {
                    MoodTile(
                        name: loc.t(.me),
                        mood: store.moods[session.me],
                        placeholder: loc.t(.moodTapToSet),
                        editable: true,
                        owner: session.me
                    )
                }
                .buttonStyle(.plain)

                MoodTile(
                    name: store.partnerName(session.me.other) ?? loc.t(.partner),
                    mood: store.moods[session.me.other],
                    placeholder: loc.t(.moodNotSet),
                    editable: false,
                    owner: session.me.other
                )
            }
            supportRow
        }
        .animation(.easeInOut, value: store.moods[session.me.other])
        .glassCard()
        .sensoryFeedback(.success, trigger: careSent)
    }

    /// «Отправить поддержку»: появляется, когда у партнёра статус вроде «Устала» или «Скучаю».
    @ViewBuilder
    private var supportRow: some View {
        if let status = store.moods[session.me.other]?.moodStatus, status.needsCare {
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.t(.sendSupport))
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(Palette.rose)
                HStack(spacing: 8) {
                    ForEach(CarePing.Kind.allCases, id: \.self) { kind in
                        Button {
                            store.sendCare(kind, from: session.me)
                            careSent += 1
                        } label: {
                            Text(CarePing(type: kind, senderId: session.me).emoji + " " + loc.t(careKey(kind)))
                                .font(.appCaption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func careKey(_ kind: CarePing.Kind) -> L {
        switch kind {
        case .sakura: return .careSakura
        case .hearts: return .careHearts
        case .hugSparkle: return .careHug
        }
    }
}

// MARK: - Countdown

struct CountdownCard: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardLabel(text: loc.t(.countdownTitle), symbol: "hourglass")
            if let event = store.nextEvent, let days = DayKey.daysFromToday(event.date) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            CategoryDot(category: event.category, size: 10)
                            Text(loc.t(event.category.titleKey))
                                .font(.appCaption)
                                .foregroundStyle(Palette.inkSoft)
                        }
                        Text(event.title)
                            .font(.appTitle(loc.language, size: 22))
                            .lineLimit(2)
                        if let date = DayKey.date(event.date) {
                            Text(loc.formatted(date, template: "EEEEdMMMM") + (event.time.map { " · \($0)" } ?? ""))
                                .font(.appSubheadline)
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                    Spacer(minLength: 8)
                    daysBadge(days)
                }
            } else {
                HStack {
                    Text(loc.t(.countdownEmpty))
                        .font(.appBody)
                        .foregroundStyle(Palette.inkSoft)
                    Spacer()
                    Button(loc.t(.countdownAction)) { session.selectedTab = .calendar }
                        .buttonStyle(GradientButtonStyle(compact: true))
                }
            }
        }
        .glassCard()
    }

    @ViewBuilder
    private func daysBadge(_ days: Int) -> some View {
        VStack(spacing: 0) {
            switch days {
            case 0:
                Text(loc.t(.today)).font(.appTitle(loc.language, size: 20))
            case 1:
                Text(loc.t(.tomorrow)).font(.appTitle(loc.language, size: 20))
            default:
                Text("\(days)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(loc.daysWord(days))
                    .font(.appCaption.weight(.semibold))
            }
        }
        .foregroundStyle(.white)
        .frame(minWidth: 84, minHeight: 84)
        .padding(.horizontal, 6)
        .background(Palette.accentGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Mood

struct MoodTile: View {
    let name: String
    let mood: Mood?
    let placeholder: String
    let editable: Bool
    var owner: Partner = .a

    @Environment(LocalizationManager.self) private var loc

    private var tint: Color { mood?.moodStatus?.tint ?? Color.white }

    /// Статус (если выбран) + текст.
    private var subtitle: String {
        guard let mood else { return placeholder }
        let status = mood.moodStatus?.title(loc.language, owner: owner)
        let parts = [status, mood.text.isEmpty ? nil : mood.text].compactMap { $0 }
        return parts.isEmpty ? " " : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(mood?.emoji.isEmpty == false ? mood!.emoji : "🤍")
                    .font(.system(size: 34))
                Spacer()
                if editable {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(Palette.rose.opacity(0.7))
                }
            }
            Text(name)
                .font(.appSubheadline.weight(.semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.appCaption)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(2, reservesSpace: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.7), tint.opacity(0.9)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.8), value: mood)
    }
}

struct MoodSheet: View {
    let current: Mood?

    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var emoji = "😊"
    @State private var text = ""
    @State private var status: MoodStatus?
    @State private var saved = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        CardLabel(text: loc.t(.moodStatus), symbol: "sparkles")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                            ForEach(MoodStatus.allCases) { item in
                                let selected = status == item
                                Button {
                                    status = selected ? nil : item
                                    if !selected { emoji = item.emoji }
                                } label: {
                                    Text("\(item.emoji) \(item.title(loc.language, owner: session.me))")
                                        .font(.appSubheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(Capsule().fill(selected ? item.tint : Color.white.opacity(0.7)))
                                        .overlay(Capsule().strokeBorder(selected ? Palette.rose : .clear, lineWidth: 1.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(Mood.choices, id: \.self) { item in
                            Button { emoji = item } label: {
                                Text(item)
                                    .font(.system(size: 32))
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(emoji == item ? Palette.sakura : Color.white.opacity(0.7))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(emoji == item ? Palette.rose : .clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    SoftField(placeholder: loc.t(.moodStatusPlaceholder), text: $text)
                        .onChange(of: text) { _, newValue in
                            if newValue.count > 40 { text = String(newValue.prefix(40)) }
                        }
                }
                .padding(20)
            }
            .background(WatercolorBackground())
            .navigationTitle(loc.t(.moodSheetTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.save)) {
                        store.setMood(emoji: emoji, text: text.trimmingCharacters(in: .whitespaces), status: status, for: session.me)
                        saved += 1
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.selection, trigger: emoji)
            .sensoryFeedback(.success, trigger: saved)
        }
        .onAppear {
            if let current {
                emoji = current.emoji.isEmpty ? "😊" : current.emoji
                text = current.text
                status = current.moodStatus
            }
        }
    }
}

// MARK: - Question of the day

struct QuestionOfDayCard: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardLabel(text: loc.t(.qotdTitle), symbol: "sparkles")
            if let question = store.questionOfTheDay(me: session.me) {
                if let category = QuestionBank.shared.category(id: question.category) {
                    Text(category.title(loc.language))
                        .font(.appCaption)
                        .foregroundStyle(Palette.inkSoft)
                }
                Text(question.prompt(loc.language))
                    .font(.appTitle(loc.language, size: 20))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button(loc.t(.qotdAnswer)) {
                        session.focusedQuestionId = question.id
                        session.selectedTab = .quiz
                    }
                    .buttonStyle(GradientButtonStyle(compact: true))
                }
            } else {
                Text(loc.t(.qotdAllDone))
                    .font(.appBody)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .glassCard()
    }
}
