import SwiftUI

struct LockScreenView: View {
    @Environment(AppSession.self) private var session
    @Environment(LocalizationManager.self) private var loc

    @State private var pin = ""
    @State private var wrong = false
    @State private var shake: CGFloat = 0
    @State private var successTrigger = 0
    @State private var errorTrigger = 0

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "bio", "0", "del"]

    var body: some View {
        ZStack {
            WatercolorBackground()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Palette.accentGradient)
                    Text(loc.t(.enterPin))
                        .font(.appTitle(loc.language, size: 24))
                    Text(wrong ? loc.t(.wrongPin) : loc.t(.lockHint))
                        .font(.appSubheadline)
                        .foregroundStyle(wrong ? Palette.rose : Palette.inkSoft)
                }

                HStack(spacing: 18) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < pin.count ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Color.white.opacity(0.8)))
                            .overlay(Circle().strokeBorder(Palette.rose.opacity(0.5), lineWidth: 1))
                            .frame(width: 16, height: 16)
                    }
                }
                .modifier(ShakeEffect(animatableData: shake))

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(78), spacing: 22), count: 3), spacing: 18) {
                    ForEach(keys, id: \.self) { key in
                        keyButton(key)
                    }
                }
                Spacer()
            }
            .padding()
        }
        .sensoryFeedback(.success, trigger: successTrigger)
        .sensoryFeedback(.error, trigger: errorTrigger)
        .task { await tryBiometrics() }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        switch key {
        case "bio":
            if session.faceIDEnabled && Biometrics.isAvailable {
                Button { Task { await tryBiometrics() } } label: {
                    Image(systemName: "faceid").font(.system(size: 28)).foregroundStyle(Palette.rose)
                        .frame(width: 78, height: 78)
                }
                .accessibilityLabel(loc.t(.useFaceID))
            } else {
                Color.clear.frame(width: 78, height: 78)
            }
        case "del":
            Button {
                if !pin.isEmpty { pin.removeLast() }
            } label: {
                Image(systemName: "delete.left").font(.system(size: 24)).foregroundStyle(Palette.inkSoft)
                    .frame(width: 78, height: 78)
            }
        default:
            Button { press(key) } label: {
                Text(key)
                    .font(.system(size: 30, weight: .regular, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 78, height: 78)
                    .background(Color.white.opacity(0.65), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
            }
        }
    }

    private func press(_ digit: String) {
        guard pin.count < 4 else { return }
        wrong = false
        pin.append(digit)
        guard pin.count == 4 else { return }
        if session.unlock(pin: pin) {
            successTrigger += 1
            pin = ""
        } else {
            errorTrigger += 1
            wrong = true
            withAnimation(.linear(duration: 0.4)) { shake += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pin = "" }
        }
    }

    private func tryBiometrics() async {
        await session.unlockWithBiometrics(reason: loc.t(.unlockReason))
        if !session.isLocked { successTrigger += 1 }
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}
