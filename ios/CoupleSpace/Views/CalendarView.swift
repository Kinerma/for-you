import SwiftUI

struct CalendarView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    @State private var vm = CalendarViewModel()
    @State private var planEditor: PlanEditorTarget?
    @State private var addingIdea = false
    @State private var scheduledTrigger = 0
    @State private var showingSwipe = false
    @State private var showingWheel = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TopBar(title: loc.t(.tabCalendar))
                monthCard
                dayCard
                wishlistCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(WatercolorBackground())
        .sheet(item: $planEditor) { target in
            PlanEditorSheet(target: target)
        }
        .sheet(isPresented: $addingIdea) {
            IdeaEditorSheet()
        }
        .fullScreenCover(isPresented: $showingSwipe) {
            SwipeMatchView()
        }
        .sheet(isPresented: $showingWheel) {
            WheelOfFortuneView()
        }
        .sensoryFeedback(.success, trigger: scheduledTrigger)
    }

    // MARK: Month grid

    private var monthCard: some View {
        let cal = loc.calendar
        return VStack(spacing: 14) {
            HStack {
                Text(loc.formatted(vm.month, template: "yMMMM"))
                    .font(.appTitle(loc.language, size: 20))
                Spacer()
                CircleIconButton(systemName: "chevron.left") { withAnimation { vm.shiftMonth(-1, calendar: cal) } }
                Button(loc.t(.today)) { withAnimation { vm.goToToday(calendar: cal) } }
                    .buttonStyle(SoftButtonStyle())
                CircleIconButton(systemName: "chevron.right") { withAnimation { vm.shiftMonth(1, calendar: cal) } }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(vm.weekdaySymbols(calendar: cal).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
                ForEach(Array(vm.gridDays(calendar: cal).enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day, calendar: cal)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }

            HStack(spacing: 12) {
                ForEach(PlanCategory.allCases) { cat in
                    HStack(spacing: 4) {
                        CategoryDot(category: cat, size: 7)
                        Text(loc.t(cat.titleKey))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .minimumScaleFactor(0.7)
        }
        .glassCard()
        .sensoryFeedback(.selection, trigger: vm.selectedDate)
    }

    private func dayCell(_ day: Date, calendar cal: Calendar) -> some View {
        let selected = cal.isDate(day, inSameDayAs: vm.selectedDate)
        let today = cal.isDateInToday(day)
        let cats = store.categories(on: DayKey.string(day))
        return Button {
            withAnimation(.snappy) { vm.selectedDate = day }
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(.callout, design: .rounded).weight(selected || today ? .bold : .regular))
                    .foregroundStyle(selected ? Color.white : Palette.ink)
                    .frame(width: 34, height: 34)
                    .background {
                        if selected {
                            Circle().fill(Palette.accentGradient)
                        } else if today {
                            Circle().strokeBorder(Palette.rose, lineWidth: 1.5)
                        }
                    }
                HStack(spacing: 2) {
                    ForEach(cats) { CategoryDot(category: $0, size: 5) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Selected day

    private var dayCard: some View {
        let plans = store.events(on: vm.selectedDate)
        return VStack(alignment: .leading, spacing: 12) {
            Text(loc.formatted(vm.selectedDate, template: "EEEEdMMMM"))
                .font(.appTitle(loc.language, size: 19))

            if plans.isEmpty {
                Text(loc.t(.noPlans))
                    .font(.appSubheadline)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ForEach(plans) { plan in
                    Button { planEditor = .edit(plan) } label: { planRow(plan) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { store.delete(plan) } label: {
                                Label(loc.t(.delete), systemImage: "trash")
                            }
                        }
                }
            }

            Button(loc.t(.addPlan)) { planEditor = .new(vm.selectedDate) }
                .buttonStyle(GradientButtonStyle(compact: true))
        }
        .glassCard()
    }

    private func planRow(_ plan: PlanEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(plan.category.color).frame(width: 5)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(plan.title).font(.appBody.weight(.semibold))
                    Spacer()
                    if let time = plan.time {
                        Text(time).font(.appSubheadline.monospacedDigit()).foregroundStyle(Palette.inkSoft)
                    }
                }
                Text(loc.t(plan.category.titleKey))
                    .font(.appCaption)
                    .foregroundStyle(plan.category.color)
                if !plan.note.isEmpty {
                    Text(plan.note)
                        .font(.appSubheadline)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }

    // MARK: Wishlist

    private var wishlistCard: some View {
        let ideas = store.ideas.sorted { a, b in
            if a.isScheduled != b.isScheduled { return !a.isScheduled }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardLabel(text: loc.t(.wishlist), symbol: "sparkles.rectangle.stack")
                Spacer()
                Button(loc.t(.addIdea)) { addingIdea = true }
                    .buttonStyle(SoftButtonStyle())
            }

            HStack(spacing: 8) {
                Button { showingSwipe = true } label: {
                    Label(loc.t(.pickTogether), systemImage: "heart.square.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GradientButtonStyle(compact: true))
                Button { showingWheel = true } label: {
                    Label(loc.t(.wheel), systemImage: "circle.dotted.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle())
            }

            if ideas.isEmpty {
                Text(loc.t(.wishlistEmpty))
                    .font(.appSubheadline)
                    .foregroundStyle(Palette.inkSoft)
            }

            ForEach(ideas) { idea in
                HStack(spacing: 12) {
                    Image(systemName: idea.category.symbol)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(idea.category.color, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(idea.title)
                            .font(.appBody.weight(.semibold))
                            .strikethrough(idea.isScheduled, color: Palette.inkSoft)
                        if !idea.note.isEmpty {
                            Text(idea.note).font(.appCaption).foregroundStyle(Palette.inkSoft).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 6)
                    if idea.isScheduled {
                        Label(loc.t(.scheduled), systemImage: "checkmark")
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(Palette.walk)
                            .labelStyle(.iconOnly)
                    }
                    Button(loc.t(.toCalendar)) {
                        store.schedule(idea, on: vm.selectedDate, by: session.me)
                        scheduledTrigger += 1
                    }
                    .buttonStyle(GradientButtonStyle(compact: true))
                }
                .padding(10)
                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(idea.isScheduled ? 0.7 : 1)
                .contextMenu {
                    Button(role: .destructive) { store.delete(idea) } label: {
                        Label(loc.t(.delete), systemImage: "trash")
                    }
                }
            }
        }
        .glassCard()
    }
}

// MARK: - Plan editor

enum PlanEditorTarget: Identifiable {
    case new(Date)
    case edit(PlanEvent)

    var id: String {
        switch self {
        case .new(let date): return "new-\(DayKey.string(date))"
        case .edit(let event): return event.id
        }
    }
}

struct PlanEditorSheet: View {
    let target: PlanEditorTarget

    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date()
    @State private var hasTime = false
    @State private var time = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var category: PlanCategory = .food
    @State private var note = ""
    @State private var saved = 0

    private var existing: PlanEvent? {
        if case .edit(let event) = target { return event }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SoftField(placeholder: loc.t(.planTitle), text: $title)

                    VStack(alignment: .leading, spacing: 10) {
                        DatePicker(loc.t(.planDate), selection: $date, displayedComponents: .date)
                        Toggle(loc.t(.planHasTime), isOn: $hasTime.animation())
                        if hasTime {
                            DatePicker(loc.t(.planTime), selection: $time, displayedComponents: .hourAndMinute)
                        }
                    }
                    .font(.appBody)
                    .environment(\.locale, loc.locale)
                    .glassCard(padding: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        CardLabel(text: loc.t(.planCategory))
                        CategoryPicker(selection: $category)
                    }
                    .glassCard(padding: 16)

                    SoftField(placeholder: loc.t(.planNote), text: $note, axis: .vertical)

                    if let existing {
                        Button(role: .destructive) {
                            store.delete(existing)
                            dismiss()
                        } label: {
                            Label(loc.t(.delete), systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SoftButtonStyle())
                        .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(WatercolorBackground())
            .navigationTitle(existing == nil ? loc.t(.newPlan) : loc.t(.plan))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.save), action: save)
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sensoryFeedback(.success, trigger: saved)
        }
        .onAppear(perform: load)
    }

    private func load() {
        switch target {
        case .new(let day):
            date = day
        case .edit(let event):
            title = event.title
            date = DayKey.date(event.date) ?? Date()
            if let t = event.time, let parsed = DayKey.time(t) {
                hasTime = true
                time = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: parsed),
                    minute: Calendar.current.component(.minute, from: parsed),
                    second: 0, of: Date()) ?? time
            }
            category = event.category
            note = event.note
        }
    }

    private func save() {
        var event = existing ?? PlanEvent(title: "", date: "", category: category, note: "", createdBy: session.me)
        event.title = title.trimmingCharacters(in: .whitespaces)
        event.date = DayKey.string(date)
        event.time = hasTime ? DayKey.timeString(time) : nil
        event.category = category
        event.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        store.save(event)
        saved += 1
        dismiss()
    }
}

// MARK: - Idea editor

struct IdeaEditorSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category: PlanCategory = .food
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SoftField(placeholder: loc.t(.planTitle), text: $title)
                    VStack(alignment: .leading, spacing: 10) {
                        CardLabel(text: loc.t(.planCategory))
                        CategoryPicker(selection: $category)
                    }
                    .glassCard(padding: 16)
                    SoftField(placeholder: loc.t(.planNote), text: $note, axis: .vertical)
                }
                .padding(20)
            }
            .background(WatercolorBackground())
            .navigationTitle(loc.t(.newIdea))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.save)) {
                        store.save(Idea(
                            title: title.trimmingCharacters(in: .whitespaces),
                            category: category,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            createdBy: session.me
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
