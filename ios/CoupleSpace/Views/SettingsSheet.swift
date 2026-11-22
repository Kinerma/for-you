import SwiftUI

struct SettingsSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var copied = false
    @State private var confirmLeave = false

    var body: some View {
        @Bindable var session = session
        @Bindable var loc = loc

        NavigationStack {
            Form {
                Section(loc.t(.name)) {
                    TextField(loc.t(.yourName), text: $name)
                        .onSubmit(saveName)
                }

                Section(loc.t(.language)) {
                    Picker(loc.t(.language), selection: $loc.language) {
                        ForEach(AppLanguage.allCases) { Text($0.shortLabel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section(loc.t(.security)) {
                    Toggle(loc.t(.faceID), isOn: $session.faceIDEnabled)
                        .disabled(!Biometrics.isAvailable)
                    NavigationLink(loc.t(.changePin)) { ChangePinView() }
                }

                Section {
                    HStack {
                        Text(session.roomId)
                            .font(.system(.title2, design: .monospaced).weight(.semibold))
                            .foregroundStyle(Palette.rose)
                            .textSelection(.enabled)
                        Spacer()
                        Button(copied ? loc.t(.copied) : loc.t(.copy)) {
                            UIPasteboard.general.string = session.roomId
                            copied = true
                        }
                        .buttonStyle(SoftButtonStyle())
                        ShareLink(item: session.roomId) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel(loc.t(.share))
                    }
                    Label(store.isCloud ? loc.t(.syncOn) : loc.t(.syncOff),
                          systemImage: store.isCloud ? "icloud.fill" : "iphone")
                        .font(.appCaption)
                        .foregroundStyle(Palette.inkSoft)
                } header: {
                    Text(loc.t(.roomCode))
                } footer: {
                    Text(loc.t(.roomHint))
                }

                Section {
                    Button(loc.t(.leaveRoom), role: .destructive) { confirmLeave = true }
                } footer: {
                    Text(loc.t(.leaveRoomConfirm))
                }
            }
            .scrollContentBackground(.hidden)
            .background(WatercolorBackground())
            .navigationTitle(loc.t(.settings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.done)) {
                        saveName()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(loc.t(.leaveRoom), isPresented: $confirmLeave, titleVisibility: .visible) {
                Button(loc.t(.leaveRoom), role: .destructive, action: leave)
                Button(loc.t(.cancel), role: .cancel) {}
            } message: {
                Text(loc.t(.leaveRoomConfirm))
            }
        }
        .onAppear { name = session.name }
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != session.name else { return }
        session.name = trimmed
        store.setProfile(name: trimmed, language: loc.language, for: session.me)
    }

    private func leave() {
        PushManager.unsubscribe(roomId: session.roomId, partner: session.me)
        store.disconnect()
        dismiss()
        session.leaveRoom()
    }
}

struct ChangePinView: View {
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var newPin = ""
    @State private var repeatPin = ""
    @State private var error: L?
    @State private var success = 0

    var body: some View {
        Form {
            Section {
                pinField(loc.t(.currentPin), text: $current)
                pinField(loc.t(.newPin), text: $newPin)
                pinField(loc.t(.repeatPin), text: $repeatPin)
            } footer: {
                if let error {
                    Text(loc.t(error)).foregroundStyle(.red)
                }
            }
            Section {
                Button(loc.t(.save), action: save)
                    .disabled(current.count != 4 || newPin.count != 4 || repeatPin.count != 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(WatercolorBackground())
        .navigationTitle(loc.t(.changePin))
        .sensoryFeedback(.success, trigger: success)
    }

    private func pinField(_ title: String, text: Binding<String>) -> some View {
        SecureField(title, text: text)
            .keyboardType(.numberPad)
            .onChange(of: text.wrappedValue) { _, value in
                let digits = String(value.filter(\.isNumber).prefix(4))
                if digits != value { text.wrappedValue = digits }
            }
    }

    private func save() {
        guard current == PinStore.current else { error = .pinWrong; return }
        guard newPin == repeatPin else { error = .pinMismatch; return }
        PinStore.save(newPin)
        error = nil
        success += 1
        dismiss()
    }
}
