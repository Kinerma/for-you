import SwiftUI

/// Реакции и мини-комментарии под карточкой в «Наших ответах» (ТЗ v2, 3.2).
/// Показывается, когда ответили оба: так приписки не раскрывают ответ раньше времени.
struct AnswerThreadView: View {
    let answer: QuizAnswer

    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    @State private var comments: [QuizComment] = []
    @State private var subscription: Subscription?
    @State private var draft = ""
    @State private var reactTrigger = 0

    private var me: Partner { session.me }
    private var myReaction: String? { answer.reaction(for: me) }
    private var partnerReaction: String? { answer.reaction(for: me.other) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            reactionsRow

            if !comments.isEmpty {
                VStack(spacing: 6) {
                    ForEach(comments) { comment in
                        bubble(comment)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(loc.t(.commentPlaceholder), text: $draft, axis: .vertical)
                    .font(.appSubheadline)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .onChange(of: draft) { _, value in
                        if value.count > 200 { draft = String(value.prefix(200)) }
                    }
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Palette.accentGradient, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                .accessibilityLabel(loc.t(.quizSend))
            }
        }
        .padding(.top, 4)
        .onAppear {
            subscription = store.observeComments(questionId: answer.questionId) { comments = $0 }
        }
        .onDisappear {
            subscription?.cancelNow()
            subscription = nil
        }
        .sensoryFeedback(.impact(weight: .light), trigger: reactTrigger)
    }

    // MARK: Reactions

    private var reactionsRow: some View {
        HStack(spacing: 6) {
            ForEach(QuizAnswer.reactionChoices, id: \.self) { emoji in
                let selected = myReaction == emoji
                Button {
                    store.setReaction(selected ? nil : emoji, questionId: answer.questionId, as: me)
                    reactTrigger += 1
                } label: {
                    Text(emoji)
                        .font(.system(size: 20))
                        .frame(width: 38, height: 34)
                        .background(
                            Capsule().fill(selected ? Palette.sakura : Color.white.opacity(0.6))
                        )
                        .overlay(Capsule().strokeBorder(selected ? Palette.rose : .clear, lineWidth: 1.5))
                        .scaleEffect(selected ? 1.08 : 1)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
            if let partnerReaction {
                HStack(spacing: 4) {
                    Text(store.partnerName(me.other) ?? loc.t(.partner))
                        .font(.appCaption)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                    Text(partnerReaction).font(.system(size: 20))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: myReaction)
        .animation(.spring(duration: 0.3), value: partnerReaction)
    }

    // MARK: Comments

    private func bubble(_ comment: QuizComment) -> some View {
        let mine = comment.senderId == me
        return HStack {
            if mine { Spacer(minLength: 40) }
            Text(comment.text)
                .font(.appSubheadline)
                .foregroundStyle(mine ? Color.white : Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if mine {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.accentGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.lavender.opacity(0.7))
                    }
                }
                .contextMenu {
                    if mine {
                        Button(role: .destructive) {
                            store.deleteComment(comment, questionId: answer.questionId)
                        } label: {
                            Label(loc.t(.delete), systemImage: "trash")
                        }
                    }
                }
            if !mine { Spacer(minLength: 40) }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addComment(text, questionId: answer.questionId, as: me)
        draft = ""
    }
}
