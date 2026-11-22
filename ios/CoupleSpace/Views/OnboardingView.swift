import SwiftUI

/// Первый запуск: роль, имя и вход в общую комнату по коду.
struct OnboardingView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    @State private var role: Partner = .a
    @State private var name = ""
    @State private var joining = false
    @State private var code = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var normalizedCode: String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }
    private var canContinue: Bool {
        !trimmedName.isEmpty && (!joining || normalizedCode.count >= 4)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    LanguageSwitcher()
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Palette.accentGradient)
                    Text(loc.t(.onbTitle))
                        .font(.appTitle(loc.language, size: 34))
                    Text(loc.t(.onbSubtitle))
                        .font(.appBody)
                        .foregroundStyle(Palette.inkSoft)
                }

                VStack(alignment: .leading, spacing: 14) {
                    CardLabel(text: loc.t(.whoAreYou), symbol: "person.2.fill")
                    HStack(spacing: 10) {
                        roleButton(.a, title: loc.t(.partnerA))
                        roleButton(.b, title: loc.t(.partnerB))
                    }
                    SoftField(placeholder: loc.t(.yourName), text: $name)
                        .textContentType(.givenName)
                }
                .glassCard()

                VStack(alignment: .leading, spacing: 14) {
                    Picker("", selection: $joining) {
                        Text(loc.t(.createRoom)).tag(false)
                        Text(loc.t(.joinRoom)).tag(true)
                    }
                    .pickerStyle(.segmented)

                    if joining {
                        SoftField(placeholder: loc.t(.roomCodePlaceholder), text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.title3, design: .monospaced))
                    }

                    Text(loc.t(.defaultPinNote))
                        .font(.appCaption)
                        .foregroundStyle(Palette.inkSoft)
                }
                .glassCard()

                Button(loc.t(.continueAction), action: submit)
                    .buttonStyle(GradientButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(!canContinue)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .sensoryFeedback(.selection, trigger: role)
    }

    private func roleButton(_ partner: Partner, title: String) -> some View {
        let selected = role == partner
        return Button {
            role = partner
        } label: {
            VStack(spacing: 6) {
                Image(systemName: partner == .a ? "sun.max.fill" : "moon.stars.fill")
                    .font(.title2)
                Text(title).font(.appSubheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(selected ? Color.white : Palette.ink)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Color.white.opacity(0.7)))
            }
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        guard canContinue else { return }
        let roomId = joining ? normalizedCode : AppSession.generateRoomCode()
        store.connect(roomId: roomId)
        if !joining { store.createRoom() }
        store.setProfile(name: trimmedName, language: loc.language, for: role)
        session.completeOnboarding(role: role, name: trimmedName, roomId: roomId)
    }
}
