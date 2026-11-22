import SwiftUI

struct QuizView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    @State private var vm = QuizViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TopBar(title: loc.t(.tabQuiz))

                Picker("", selection: $vm.mode) {
                    Text(loc.t(.quizQuestions)).tag(QuizMode.questions)
                    Text(loc.t(.quizOurAnswers)).tag(QuizMode.answers)
                }
                .pickerStyle(.segmented)

                switch vm.mode {
                case .questions: questionsMode
                case .answers: AnswersArchiveView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(WatercolorBackground())
        .onAppear(perform: consumeFocus)
        .onChange(of: session.focusedQuestionId) { _, _ in consumeFocus() }
    }

    private func consumeFocus() {
        guard let id = session.focusedQuestionId else { return }
        withAnimation { vm.focus(on: id) }
        session.focusedQuestionId = nil
    }

    @ViewBuilder
    private var questionsMode: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: loc.t(.quizAll), id: nil)
                ForEach(QuestionBank.shared.categories) { category in
                    filterChip(title: category.title(loc.language), id: category.id)
                }
            }
        }

        if let question = vm.current {
            QuestionCard(question: question) {
                withAnimation(.easeInOut) {
                    vm.advanceToNextUnanswered { store.myAnswer($0, me: session.me) != nil }
                }
            }
            .id(question.id)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))

            HStack {
                Button { withAnimation { vm.previous() } } label: {
                    Label(loc.t(.quizPrevious), systemImage: "chevron.left")
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(!vm.canGoBack)
                .opacity(vm.canGoBack ? 1 : 0.4)

                Spacer()
                Text(loc.progress(vm.index + 1, vm.filtered.count))
                    .font(.appCaption)
                    .foregroundStyle(Palette.inkSoft)
                Spacer()

                Button { withAnimation { vm.next() } } label: {
                    HStack(spacing: 4) {
                        Text(loc.t(.quizNext))
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(!vm.canGoForward)
                .opacity(vm.canGoForward ? 1 : 0.4)
            }
            .sensoryFeedback(.selection, trigger: vm.index)
        }
    }

    private func filterChip(title: String, id: String?) -> some View {
        let selected = vm.categoryFilter == id
        return Button {
            withAnimation { vm.setFilter(id) }
        } label: {
            Text(title)
                .font(.appSubheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Palette.ink)
                .background {
                    Capsule().fill(selected ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Color.white.opacity(0.7)))
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Question card with Mutual Reveal

struct QuestionCard: View {
    let question: QuizQuestion
    var onAnswered: () -> Void = {}

    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    @State private var draft = ""
    @State private var editing = false

    private var myAnswer: String? { store.myAnswer(question, me: session.me) }
    private var partnerAnswer: String? { store.answer(for: question)?.answer(for: session.me.other) }
    private var partnerName: String { store.partnerName(session.me.other) ?? loc.t(.partner) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let category = QuestionBank.shared.category(id: question.category) {
                CardLabel(text: category.title(loc.language), symbol: question.type == .eitherOr ? "arrow.left.arrow.right" : "text.bubble")
            }
            Text(question.prompt(loc.language))
                .font(.appTitle(loc.language, size: 22))
                .fixedSize(horizontal: false, vertical: true)

            switch question.type {
            case .eitherOr: eitherOrBody
            case .open: openBody
            }

            Divider().overlay(Palette.sakura)

            PartnerAnswerView(
                partnerName: partnerName,
                text: partnerAnswer.map { question.display($0, lang: loc.language) },
                revealed: myAnswer != nil
            )
        }
        .glassCard(padding: 20)
        .onAppear { draft = myAnswer ?? "" }
    }

    // MARK: Either / Or

    private var eitherOrBody: some View {
        let options = question.options ?? []
        return VStack(spacing: 10) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                if index > 0 {
                    Text(loc.t(.quizOr))
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(Palette.inkSoft)
                }
                let selected = myAnswer == option.id
                Button {
                    let first = myAnswer == nil
                    store.answer(option.id, to: question, as: session.me)
                    if first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { onAnswered() }
                    }
                } label: {
                    Text(option.text(loc.language))
                        .font(.appBody.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .padding(.horizontal, 14)
                        .foregroundStyle(selected ? Color.white : Palette.ink)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(selected ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Color.white.opacity(0.75)))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(selected ? Color.clear : Palette.sakura, lineWidth: 1.5)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: myAnswer)
    }

    // MARK: Open

    @ViewBuilder
    private var openBody: some View {
        if let myAnswer, !editing {
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.t(.quizYourAnswer))
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(Palette.rose)
                Text(myAnswer)
                    .font(.appBody)
                    .fixedSize(horizontal: false, vertical: true)
                Button(loc.t(.quizChangeAnswer)) {
                    draft = myAnswer
                    editing = true
                }
                .buttonStyle(SoftButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .trailing, spacing: 10) {
                SoftField(placeholder: loc.t(.quizOpenPlaceholder), text: $draft, axis: .vertical)
                Button(loc.t(.quizSend)) {
                    let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty else { return }
                    let first = myAnswer == nil
                    store.answer(value, to: question, as: session.me)
                    editing = false
                    hideKeyboard()
                    if first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { onAnswered() }
                    }
                }
                .buttonStyle(GradientButtonStyle(compact: true))
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Ответ партнёра под мягким блюром, пока я не ответил(а).
struct PartnerAnswerView: View {
    let partnerName: String
    let text: String?
    let revealed: Bool

    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(partnerName)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(Palette.lavenderDeep)

            if let text {
                ZStack {
                    Text(text)
                        .font(.appBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .blur(radius: revealed ? 0 : 9)
                        .accessibilityHidden(!revealed)

                    if !revealed {
                        Label(loc.t(.quizAnswerToSee), systemImage: "lock.heart.fill")
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .transition(.opacity)
                    }
                }
                .padding(12)
                .background(Palette.lavender.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Text(loc.t(.quizNoAnswerYet))
                    .font(.appSubheadline)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: revealed)
        .sensoryFeedback(trigger: revealed) { old, new in
            (!old && new && text != nil) ? .success : nil
        }
    }
}

// MARK: - Archive

struct AnswersArchiveView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        let items = store.answeredQuestions
        if items.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 40))
                    .foregroundStyle(Palette.accentGradient)
                Text(loc.t(.quizArchiveEmpty))
                    .font(.appBody)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .glassCard(padding: 28)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    archiveRow(item.question, item.answer)
                }
            }
        }
    }

    private func archiveRow(_ question: QuizQuestion, _ answer: QuizAnswer) -> some View {
        let me = session.me
        let mine = answer.answer(for: me)
        let theirs = answer.answer(for: me.other)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let category = QuestionBank.shared.category(id: question.category) {
                    CardLabel(text: category.title(loc.language))
                }
                Spacer()
                Text(answer.updatedAt.formatted(.relative(presentation: .named).locale(loc.locale)))
                    .font(.appCaption)
                    .foregroundStyle(Palette.inkSoft)
            }
            Text(question.prompt(loc.language))
                .font(.appTitle(loc.language, size: 18))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(session.name.isEmpty ? loc.t(.me) : session.name)
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(Palette.rose)
                Text(mine.map { question.display($0, lang: loc.language) } ?? loc.t(.quizNoAnswerYet))
                    .font(.appBody)
                    .foregroundStyle(mine == nil ? Palette.inkSoft : Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PartnerAnswerView(
                partnerName: store.partnerName(me.other) ?? loc.t(.partner),
                text: theirs.map { question.display($0, lang: loc.language) },
                revealed: mine != nil
            )

            if mine == nil {
                Button(loc.t(.qotdAnswer)) {
                    session.focusedQuestionId = question.id
                }
                .buttonStyle(GradientButtonStyle(compact: true))
            }
        }
        .glassCard()
    }
}
