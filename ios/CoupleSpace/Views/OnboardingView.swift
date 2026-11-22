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
    @State private var pin = ""
    @State private var pinRepeat = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var normalizedCode: String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }
    private var pinValid: Bool { pin.count == 4 && pin == pinRepeat }
    private var pinMismatch: Bool { pinRepeat.count == 4 && pin.count == 4 && pin != pinRepeat }
    private var canContinue: Bool {
        !trimmedName.isEmpty && (joining ? normalizedCode.count >= 4 : pinValid)
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

                    if !joining {
                    VStack(alignment: .leading, spacing: 10) {
                        CardLabel(text: loc.t(.createPin), symbol: "lock.fill")
                        pinField(loc.t(.createPin), text: $pin)
                        pinField(loc.t(.confirmPin), text: $pinRepeat)
                        Text(pinMismatch ? loc.t(.pinsDontMatch) : loc.t(.pinSetupHint))
                            .font(.appCaption)
                            .foregroundStyle(pinMismatch ? Palette.rose : Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    }
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
                Text(partner == .a ? "♂" : "♀")
                    .font(.system(size: 30, weight: .semibold))
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

    private func pinField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .font(.system(.title3, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.sakura, lineWidth: 1))
            .onChange(of: text.wrappedValue) { _, value in
                let digits = String(value.filter(\.isNumber).prefix(4))
                if digits != value { text.wrappedValue = digits }
            }
    }

    private func submit() {
        guard canContinue else { return }
        let roomId = joining ? normalizedCode : AppSession.generateRoomCode()
        store.connect(roomId: roomId)
        if !joining {
            store.createRoom()
            let pinHash = PinStore.hash(pin, roomId: roomId)
            PinStore.saveHash(pinHash)
            store.setPinHash(pinHash)
        }
        store.setProfile(name: trimmedName, language: loc.language, for: role)
        session.completeOnboarding(role: role, name: trimmedName, roomId: roomId)
    }
}
