import SwiftUI

/// «Насколько хорошо ты меня знаешь?» (ТЗ v2, 3.1).
/// Еженедельный раунд из 5 вопросов: сначала ответ за себя, потом догадка об ответе партнёра.
struct GuessModeView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    @State private var showingRewards = false
    @State private var draftSelf: String?
    @State private var stepTrigger = 0
    @State private var doneTrigger = 0

    private let roundKey = RoomStore.weekRoundKey()
    private let questions = RoomStore.roundQuestions()

    private var me: Partner { session.me }
    private var partnerName: String { store.partnerName(me.other) ?? loc.t(.partner) }

    private var entries: [(QuizQuestion, GuessEntry)] {
        questions.map { ($0, store.guessEntry(roundKey: roundKey, question: $0)) }
    }

    private var myNext: QuizQuestion? {
        entries.first { !$0.1.isDone(by: me) }?.0
    }

    private var roundComplete: Bool { entries.allSatisfy { $0.1.isComplete } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            starsHeader

            if let question = myNext {
                playCard(question)
            } else if roundComplete {
                resultsCard
            } else {
                waitingCard
            }
        }
        .sheet(isPresented: $showingRewards) { RewardsSheet() }
        .sensoryFeedback(.selection, trigger: stepTrigger)
        .sensoryFeedback(.success, trigger: doneTrigger)
    }

    // MARK: Header

    private var starsHeader: some View {
        let stars = store.totalStars
        let next = AppIconReward.allCases.first { $0.starsRequired > stars }
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.t(.guessTitle))
                    .font(.appTitle(loc.language, size: 19))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text("★ \(stars)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(hex: 0xE0A93B))
                    Text(loc.t(.guessStarsTotal))
                        .font(.appCaption)
                        .foregroundStyle(Palette.inkSoft)
                }
                if let next {
                    ProgressView(value: Double(stars), total: Double(next.starsRequired))
                        .tint(Palette.rose)
                    Text(loc.t(.starsToUnlock).replacingOccurrences(of: "{n}", with: "\(next.starsRequired - stars)")
                         + " · " + loc.t(next.titleKey))
                        .font(.appCaption)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)
            Button { showingRewards = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: "gift.fill").font(.title2)
                    Text(loc.t(.rewards)).font(.appCaption.weight(.semibold))
                }
                .foregroundStyle(Palette.rose)
                .frame(width: 72, height: 72)
                .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .glassCard()
    }

    // MARK: Play

    private func playCard(_ question: QuizQuestion) -> some View {
        let index = (questions.firstIndex(of: question) ?? 0) + 1
        let options = question.options ?? []
        let guessing = draftSelf != nil

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                CardLabel(text: loc.t(.guessRoundOfWeek), symbol: "calendar")
                Spacer()
                Text(loc.progress(index, questions.count))
                    .font(.appCaption)
                    .foregroundStyle(Palette.inkSoft)
            }

            Text(question.prompt(loc.language))
                .font(.appTitle(loc.language, size: 21))
                .fixedSize(horizontal: false, vertical: true)

            Label(guessing ? loc.t(.guessStepPartner).replacingOccurrences(of: "{name}", with: partnerName)
                           : loc.t(.guessStepSelf),
                  systemImage: guessing ? "sparkle.magnifyingglass" : "person.fill")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(guessing ? Palette.lavenderDeep : Palette.rose)
                .contentTransition(.opacity)

            VStack(spacing: 10) {
                ForEach(options) { option in
                    Button { choose(option.id, question: question) } label: {
                        Text(option.text(loc.language))
                            .font(.appBody.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .padding(.horizontal, 14)
                            .foregroundStyle(Palette.ink)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(guessing ? Palette.lavender.opacity(0.6) : Color.white.opacity(0.8))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(guessing ? Palette.lavenderDeep.opacity(0.5) : Palette.sakura, lineWidth: 1.5)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            if guessing {
                Button(loc.t(.quizPrevious)) { withAnimation { draftSelf = nil } }
                    .buttonStyle(SoftButtonStyle())
            }
        }
        .glassCard(padding: 20)
        .id(question.id)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        .animation(.easeInOut, value: guessing)
    }

    private func choose(_ optionId: String, question: QuizQuestion) {
        if let mine = draftSelf {
            store.submitGuess(roundKey: roundKey, question: question, selfAnswer: mine, guess: optionId, as: me)
            let remaining = entries.filter { !$0.1.isDone(by: me) }.count
            withAnimation(.easeInOut) { draftSelf = nil }
            if remaining <= 1 { doneTrigger += 1 } else { stepTrigger += 1 }
        } else {
            withAnimation(.easeInOut) { draftSelf = optionId }
            stepTrigger += 1
        }
    }

    // MARK: Waiting & results

    private var waitingCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 36))
                .foregroundStyle(Palette.accentGradient)
            Text(loc.t(.guessWaiting).replacingOccurrences(of: "{name}", with: partnerName))
                .font(.appBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 28)
    }

    private var resultsCard: some View {
        let roundStars = entries.reduce(0) { $0 + $1.1.computedStars }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                CardLabel(text: loc.t(.guessResults), symbol: "sparkles")
                Spacer()
                Text("\(loc.t(.guessRoundStars)): ★ \(roundStars) / \(entries.count * 2)")
                    .font(.appSubheadline.weight(.bold))
                    .foregroundStyle(Color(hex: 0xE0A93B))
            }

            ForEach(questions) { question in
                let entry = store.guessEntry(roundKey: roundKey, question: question)
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.prompt(loc.language))
                        .font(.appSubheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    resultLine(name: loc.t(.me), answer: entry.selfAnswer(me), question: question,
                               guessedRight: entry.guessedRight(me))
                    resultLine(name: partnerName, answer: entry.selfAnswer(me.other), question: question,
                               guessedRight: entry.guessedRight(me.other))
                }
                .padding(12)
                .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text(loc.t(.guessNextRound))
                .font(.appCaption)
                .foregroundStyle(Palette.inkSoft)
        }
        .glassCard()
    }

    /// «Я: вариант  ✓ угадал(а) партнёра» — галочка показывает, угадал ли этот человек ответ второго.
    private func resultLine(name: String, answer: String?, question: QuizQuestion, guessedRight: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(name)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(Palette.rose)
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)
            Text(answer.map { question.display($0, lang: loc.language) } ?? "—")
                .font(.appCaption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Label(guessedRight ? loc.t(.guessRight) : loc.t(.guessWrong),
                  systemImage: guessedRight ? "star.fill" : "xmark")
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(guessedRight ? Color(hex: 0xE0A93B) : Palette.inkSoft)
                .labelStyle(.titleAndIcon)
        }
    }
}

// MARK: - Rewards

struct RewardsSheet: View {
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var currentIcon = UIApplication.shared.alternateIconName
    @State private var changed = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc.t(.rewardsHint))
                        .font(.appBody)
                        .foregroundStyle(Palette.inkSoft)
                    Text("★ \(store.totalStars)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xE0A93B))

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(AppIconReward.allCases) { reward in
                            rewardTile(reward)
                        }
                    }
                }
                .padding(20)
            }
            .background(WatercolorBackground())
            .navigationTitle(loc.t(.rewards))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.done)) { dismiss() }.fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.success, trigger: changed)
        }
    }

    private func rewardTile(_ reward: AppIconReward) -> some View {
        let unlocked = store.totalStars >= reward.starsRequired
        let inUse = currentIcon == reward.iconName
        return VStack(spacing: 10) {
            Image(reward.previewImage)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay {
                    if !unlocked {
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(Image(systemName: "lock.fill").foregroundStyle(Palette.inkSoft))
                    }
                }
            Text(loc.t(reward.titleKey))
                .font(.appSubheadline.weight(.semibold))
            if inUse {
                Text(loc.t(.iconInUse))
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(Palette.walk)
            } else if unlocked {
                Button(loc.t(.useIcon)) { setIcon(reward) }
                    .buttonStyle(GradientButtonStyle(compact: true))
            } else {
                Text("★ \(reward.starsRequired)")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 14)
    }

    private func setIcon(_ reward: AppIconReward) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(reward.iconName) { error in
            DispatchQueue.main.async {
                if error == nil {
                    currentIcon = reward.iconName
                    changed += 1
                }
            }
        }
    }
}
