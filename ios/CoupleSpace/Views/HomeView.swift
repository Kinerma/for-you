import SwiftUI

/// Главный экран в формате Bento-сетки (ТЗ «Обновлённая главная страница»).
struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.scenePhase) private var scenePhase

    @State private var editingMood = false
    @State private var editingStartDate = false
    @State private var editingMoment = false
    @State private var showingSwipe = false

    // Эффекты поверх экрана
    @State private var hugPressing = false
    @State private var hugRippleStart = Date()
    @State private var incomingHug = false
    @State private var petalsBurst: UUID?
    @State private var toast: String?
    @State private var careTrigger = 0
    @State private var handledInteraction: Date?

    private var me: Partner { session.me }
    private var partnerName: String { store.partnerName(me.other) ?? loc.t(.partner) }

    var body: some View {
        ZStack {
            WatercolorBackground(tint: store.moods[me.other]?.moodType)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    moodSection
                    bentoRow
                    DailyQuizCard()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            if hugPressing || incomingHug {
                HugRipples(start: hugRippleStart, warm: incomingHug)
                    .transition(.opacity)
            }

            if let burst = petalsBurst {
                ParticleRain(kind: .petals, count: 45, duration: 2.6)
                    .id(burst)
            }

            if let toast {
                Text(toast)
                    .font(.appSubheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: Palette.rose.opacity(0.2), radius: 10, y: 4)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hugPressing)
        .animation(.easeInOut(duration: 0.4), value: incomingHug)
        .animation(.spring(duration: 0.4), value: toast)
        .sensoryFeedback(.impact(weight: .light), trigger: careTrigger)
        .sheet(isPresented: $editingMood) {
            MoodSheet(current: store.moods[me])
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $editingStartDate) {
            RelationshipDateSheet()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $editingMoment) {
            DailyMomentSheet()
        }
        .fullScreenCover(isPresented: $showingSwipe) {
            SwipeMatchView()
        }
        .onChange(of: store.latestInteraction) { _, interaction in
            receive(interaction)
        }
    }

    // MARK: Header

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return loc.t(.goodMorning)
        case 11..<17: return loc.t(.goodDay)
        case 17..<22: return loc.t(.cozyEvening)
        default: return loc.t(.goodNight)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            TopBar(subtitle: greeting, title: session.name.isEmpty ? loc.t(.onbTitle) : session.name)

            Button { editingStartDate = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").font(.caption)
                    Text(togetherText)
                        .font(.appSubheadline.weight(.semibold))
                }
                .foregroundStyle(store.meta.daysTogether == nil ? Palette.inkSoft : Palette.rose)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var togetherText: String {
        guard let days = store.meta.daysTogether else { return loc.t(.setOurDate) }
        switch loc.language {
        case .ru: return "Мы вместе: \(days) \(loc.daysWord(days))"
        case .zhHant: return "在一起 \(days) 天"
        case .en: return "Together for \(days) \(loc.daysWord(days))"
        }
    }

    // MARK: Mood section

    private var moodSection: some View {
        HStack(spacing: 12) {
            Button { editingMood = true } label: {
                MoodCard(title: loc.t(.myMood), owner: me, mood: store.moods[me],
                         placeholder: loc.t(.moodTapToSet), footer: nil)
            }
            .buttonStyle(.plain)

            Button(action: sendCare) {
                MoodCard(title: partnerName, owner: me.other, mood: store.moods[me.other],
                         placeholder: loc.t(.moodNotSet), footer: loc.t(.tapToCare))
            }
            .buttonStyle(.plain)
        }
        .overlay {
            HugButton(pressing: $hugPressing, onStart: { hugRippleStart = Date() }, onComplete: hugCompleted)
        }
    }

    private func sendCare() {
        store.sendSupportPulse(from: me)
        careTrigger += 1
        petalsBurst = UUID()
        showToast(loc.t(.careSentToast))
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            petalsBurst = nil
        }
    }

    private func hugCompleted() {
        store.sendHugInteraction(from: me)
        showToast(loc.t(.hugSent))
    }

    /// Объятие от партнёра, пока приложение открыто: волны + несколько ударов сердца.
    private func receive(_ interaction: Interaction?) {
        guard let interaction, interaction.type == .hug, interaction.fromPartnerId != me,
              scenePhase == .active, !session.isLocked,
              Date().timeIntervalSince(interaction.createdAt) < 20,
              handledInteraction != interaction.createdAt else { return }
        handledInteraction = interaction.createdAt
        hugRippleStart = Date()
        incomingHug = true
        HeartbeatHaptics.shared.playBeats(4)
        showToast("\(partnerName) \(loc.t(.hugReceived))")
        Task {
            try? await Task.sleep(for: .seconds(4))
            incomingHug = false
        }
    }

    private func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            if toast == text { toast = nil }
        }
    }

    // MARK: Bento row

    private var bentoRow: some View {
        HStack(spacing: 12) {
            SmartCountdownCard(onEmptyTap: { showingSwipe = true })
            DailyMomentCard(onTap: { editingMoment = true })
        }
    }
}

// MARK: - Mood card

struct MoodCard: View {
    let title: String
    let owner: Partner
    let mood: Mood?
    let placeholder: String
    let footer: String?

    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)

            HStack(alignment: .center, spacing: 6) {
                Text(mood?.emoji.isEmpty == false ? mood!.emoji : "🤍")
                    .font(.system(size: 30))
                Text(statusLine)
                    .font(.appSubheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            if let text = mood?.text, !text.isEmpty {
                Text(text)
                    .font(.appCaption)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if let energy = mood?.energyLevel {
                EnergyBar(level: energy)
            }

            if let need = mood?.need {
                Text("\(need.emoji) \(loc.t(need.titleKey))")
                    .font(.appCaption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.75), in: Capsule())
            }

            if let footer {
                Text(footer)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.rose.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 196, alignment: .topLeading)
        .glassCard(padding: 14)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(mood?.moodStatus?.tint.opacity(0.55) ?? .clear)
        }
        .animation(.easeInOut(duration: 0.8), value: mood)
    }

    private var statusLine: String {
        guard let mood else { return placeholder }
        return mood.moodStatus?.title(loc.language, owner: owner) ?? (mood.text.isEmpty ? " " : "")
    }
}

/// «Заряд батарейки» 0–100%.
struct EnergyBar: View {
    let level: Int

    @Environment(LocalizationManager.self) private var loc

    private var fraction: Double { Double(min(max(level, 0), 100)) / 100 }

    private var color: Color {
        switch level {
        case ..<30: return Palette.food
        case ..<65: return Color(hex: 0xF2C27B)
        default: return Palette.walk
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: level < 30 ? "battery.25" : (level < 65 ? "battery.50" : "battery.100"))
                    .font(.caption2)
                Text("\(loc.t(.energy)) \(level)%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Palette.inkSoft)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.7))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Hug button

/// Круглая кнопка «Обнять» между карточками: удержание ~1.5 сек.
struct HugButton: View {
    @Binding var pressing: Bool
    var onStart: () -> Void
    var onComplete: () -> Void

    @Environment(LocalizationManager.self) private var loc
    @State private var done = 0

    var body: some View {
        Circle()
            .fill(Palette.accentGradient)
            .frame(width: 62, height: 62)
            .overlay(
                Image(systemName: "heart.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: pressing)
            )
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 4))
            .shadow(color: Palette.rose.opacity(0.4), radius: pressing ? 20 : 10, y: 4)
            .scaleEffect(pressing ? 1.12 : 1)
            .animation(.spring(duration: 0.35), value: pressing)
            .onLongPressGesture(minimumDuration: 1.5, maximumDistance: 40) {
                pressing = false
                done += 1
                onComplete()
            } onPressingChanged: { isPressing in
                pressing = isPressing
                if isPressing {
                    onStart()
                    HeartbeatHaptics.shared.playRising(duration: 1.5)
                } else {
                    HeartbeatHaptics.shared.cancelOneShot()
                }
            }
            .sensoryFeedback(.success, trigger: done)
            .accessibilityLabel(loc.t(.hugTitle))
            .accessibilityHint(loc.t(.hugHint))
    }
}

/// Акварельные круги-волны по всему экрану.
struct HugRipples: View {
    let start: Date
    var warm = false

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.38)
                let maxR = max(size.width, size.height) * 0.75
                let t = timeline.date.timeIntervalSince(start)
                for i in 0..<5 {
                    let phase = (t / 2.2 + Double(i) / 5).truncatingRemainder(dividingBy: 1)
                    let r = 30 + phase * maxR
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                    let color = warm ? (i.isMultiple(of: 2) ? Palette.rose : Color(hex: 0xF6B27A))
                                     : (i.isMultiple(of: 2) ? Palette.rose : Palette.lavenderDeep)
                    ctx.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.35 * (1 - phase))), lineWidth: 18)
                }
            }
            .blur(radius: 12)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Smart countdown

struct SmartCountdownCard: View {
    var onEmptyTap: () -> Void

    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        Group {
            if let event = store.nextEvent {
                Button {
                    session.focusedEventId = event.id
                    session.selectedTab = .calendar
                } label: { eventFace(event) }
            } else {
                Button(action: onEmptyTap) { emptyFace }
            }
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fit)
    }

    private func eventFace(_ event: PlanEvent) -> some View {
        let (value, unit) = remaining(event)
        let days = DayKey.daysFromToday(event.date) ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                CategoryDot(category: event.category, size: 8)
                Text(loc.t(event.category.titleKey))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
            Text(event.title)
                .font(.appSubheadline.weight(.semibold))
                .lineLimit(2)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.accentGradient)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(unit)
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            // Тонкий прогресс: чем ближе событие (в пределах 30 дней), тем полнее полоска.
            ProgressView(value: 1 - min(Double(max(days, 0)), 30) / 30)
                .tint(event.category.color)
                .scaleEffect(x: 1, y: 0.7, anchor: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(padding: 14)
    }

    /// Дни, а в последний день — часы.
    private func remaining(_ event: PlanEvent) -> (String, String) {
        let days = DayKey.daysFromToday(event.date) ?? 0
        if days >= 1 { return ("\(days)", loc.daysWord(days)) }
        if let day = DayKey.date(event.date) {
            var target = day
            if let time = event.time, let t = DayKey.time(time) {
                let cal = Calendar.current
                target = cal.date(bySettingHour: cal.component(.hour, from: t),
                                  minute: cal.component(.minute, from: t), second: 0, of: day) ?? day
            }
            let hours = Int(ceil(target.timeIntervalSinceNow / 3600))
            if hours > 0 { return ("\(hours)", loc.t(.hoursShort)) }
        }
        return (loc.t(.today), "")
    }

    private var emptyFace: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "heart.square.fill")
                .font(.system(size: 30))
                .foregroundStyle(Palette.accentGradient)
            Spacer(minLength: 0)
            Text(loc.t(.swipeTitle))
                .font(.appTitle(loc.language, size: 18))
            Text(loc.t(.swipeIdeas) + " →")
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(Palette.rose)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(padding: 14)
    }
}

// MARK: - Daily moment (polaroid)

struct DailyMomentCard: View {
    var onTap: () -> Void

    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Rectangle().fill(Palette.champagne.opacity(0.6))
                    if let moment = store.dailyMoment, let image = MomentImage.decode(moment.imageBase64) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "camera.fill").font(.title3)
                            Text(loc.t(.momentEmpty))
                                .font(.system(size: 11, design: .rounded))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(Palette.inkSoft)
                        .padding(8)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipped()

                VStack(spacing: 1) {
                    Text(caption)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    if let moment = store.dailyMoment {
                        Text("\(store.partnerName(moment.authorId) ?? "") · \(moment.updatedAt.formatted(.relative(presentation: .named).locale(loc.locale)))")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, 2)
            }
            .padding(8)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: Palette.ink.opacity(0.15), radius: 10, y: 6)
            .rotationEffect(.degrees(2))
            .padding(6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var caption: String {
        guard let moment = store.dailyMoment else { return loc.t(.momentTitle) }
        return moment.caption.isEmpty ? loc.t(.momentTitle) : moment.caption
    }
}

// MARK: - Daily quiz

struct DailyQuizCard: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    @State private var pulse = false

    var body: some View {
        let item = store.homeQuestion(me: session.me)
        Button {
            if let item {
                session.focusedQuestionId = item.question.id
                session.selectedTab = .quiz
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    CardLabel(text: loc.t(.qotdTitle), symbol: "sparkles")
                    Spacer()
                    if item?.partnerAnswered == true {
                        Text(loc.t(.partnerAnsweredBadge))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Palette.accentGradient, in: Capsule())
                    }
                }
                if let item {
                    if let category = QuestionBank.shared.category(id: item.question.category) {
                        Text(category.title(loc.language))
                            .font(.appCaption)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Text(item.question.prompt(loc.language))
                        .font(.appTitle(loc.language, size: 19))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(loc.t(.qotdAllDone))
                        .font(.appBody)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .glassCard()
            .overlay {
                if item?.partnerAnswered == true {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Palette.rose, lineWidth: 2)
                        .opacity(pulse ? 0.9 : 0.25)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                        .onAppear { pulse = true }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Relationship start date

struct RelationshipDateSheet: View {
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(loc.t(.relationshipSince), selection: $date, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, loc.locale)
                Spacer()
            }
            .padding(20)
            .background(WatercolorBackground())
            .navigationTitle(loc.t(.whenTogether))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.save)) {
                        store.setRelationshipStart(date)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear { date = store.meta.relationshipStartDate ?? Date() }
    }
}

// MARK: - Mood sheet

struct MoodSheet: View {
    let current: Mood?

    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var emoji = "😊"
    @State private var text = ""
    @State private var status: MoodStatus?
    @State private var energy: Double = 70
    @State private var need: NeedTag?
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

                    VStack(alignment: .leading, spacing: 8) {
                        CardLabel(text: "\(loc.t(.energy)): \(Int(energy))%", symbol: "battery.75")
                        Slider(value: $energy, in: 0...100, step: 5)
                            .tint(energy < 30 ? Palette.food : (energy < 65 ? Color(hex: 0xF2C27B) : Palette.walk))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CardLabel(text: loc.t(.needTitle), symbol: "hand.raised.fill")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
                            ForEach(NeedTag.allCases) { tag in
                                let selected = need == tag
                                Button { need = selected ? nil : tag } label: {
                                    Text("\(tag.emoji) \(loc.t(tag.titleKey))")
                                        .font(.appSubheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(Capsule().fill(selected ? Palette.sakura : Color.white.opacity(0.7)))
                                        .overlay(Capsule().strokeBorder(selected ? Palette.rose : .clear, lineWidth: 1.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                        ForEach(Mood.choices, id: \.self) { item in
                            Button { emoji = item } label: {
                                Text(item)
                                    .font(.system(size: 24))
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(emoji == item ? Palette.sakura : Color.white.opacity(0.7))
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
                        store.setMood(emoji: emoji, text: text.trimmingCharacters(in: .whitespaces),
                                      status: status, energy: Int(energy), need: need, for: session.me)
                        saved += 1
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.selection, trigger: emoji)
            .sensoryFeedback(.selection, trigger: need)
            .sensoryFeedback(.success, trigger: saved)
        }
        .onAppear {
            if let current {
                emoji = current.emoji.isEmpty ? "😊" : current.emoji
                text = current.text
                status = current.moodStatus
                energy = Double(current.energyLevel ?? 70)
                need = current.need
            }
        }
    }
}
