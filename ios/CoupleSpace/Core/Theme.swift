import SwiftUI

// MARK: - Palette (ТЗ, раздел 3)

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Palette {
    static let background = Color(hex: 0xFDF7F8)
    static let sakura = Color(hex: 0xF7D6E0)
    static let lavender = Color(hex: 0xE5D9F2)
    static let champagne = Color(hex: 0xFCECDD)

    static let rose = Color(hex: 0xD988A1)
    static let lavenderDeep = Color(hex: 0xA890C4)

    static let ink = Color(hex: 0x4A3540)
    static let inkSoft = Color(hex: 0x8A727E)

    static let food = Color(hex: 0xE8998D)
    static let walk = Color(hex: 0xA3C4BC)
    static let trip = Color(hex: 0xA890C4)
    static let special = Color(hex: 0xD988A1)

    static let accentGradient = LinearGradient(
        colors: [rose, lavenderDeep],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Watercolor background

struct WatercolorBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Palette.background
                Circle()
                    .fill(Palette.sakura)
                    .frame(width: w * 0.9)
                    .position(x: w * 0.1, y: h * 0.12)
                Circle()
                    .fill(Palette.lavender)
                    .frame(width: w * 0.85)
                    .position(x: w * 0.95, y: h * 0.38)
                Circle()
                    .fill(Palette.champagne)
                    .frame(width: w * 1.0)
                    .position(x: w * 0.25, y: h * 0.78)
                Circle()
                    .fill(Palette.sakura.opacity(0.7))
                    .frame(width: w * 0.6)
                    .position(x: w * 0.9, y: h * 0.95)
            }
            .blur(radius: 70)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Frosted pearl glass card

struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: shape)
            .background(Color.white.opacity(0.65), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
            .shadow(color: Palette.rose.opacity(0.16), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func glassCard(padding: CGFloat = 18) -> some View {
        modifier(GlassCardModifier(padding: padding))
    }
}

// MARK: - Buttons

struct GradientButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        GradientButtonBody(configuration: configuration, compact: compact)
    }

    private struct GradientButtonBody: View {
        let configuration: Configuration
        let compact: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(compact ? .subheadline : .body, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, compact ? 14 : 22)
                .padding(.vertical, compact ? 8 : 14)
                .frame(minHeight: compact ? 34 : 50)
                .background(Palette.accentGradient, in: Capsule())
                .shadow(color: Palette.rose.opacity(0.3), radius: 10, x: 0, y: 5)
                .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 34)
            .background(Color.white.opacity(configuration.isPressed ? 0.5 : 0.75), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
    }
}

// MARK: - Typography

extension Font {
    /// Заголовки: serif, для zh-Hant — PingFang TC (на iOS это надёжный системный шрифт).
    static func appTitle(_ lang: AppLanguage, size: CGFloat = 22) -> Font {
        switch lang {
        case .zhHant:
            return .custom("PingFangTC-Semibold", size: size, relativeTo: .title2)
        default:
            return .system(size: size, weight: .semibold, design: .serif)
        }
    }

    static let appBody = Font.system(.body, design: .rounded)
    static let appCaption = Font.system(.caption, design: .rounded)
    static let appSubheadline = Font.system(.subheadline, design: .rounded)
}
