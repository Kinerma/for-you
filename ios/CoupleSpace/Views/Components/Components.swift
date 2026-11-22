import SwiftUI

/// Переключатель RU / 繁中 / EN — мгновенно меняет язык всего интерфейса.
struct LanguageSwitcher: View {
    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppLanguage.allCases) { lang in
                let selected = loc.language == lang
                Button {
                    withAnimation(.snappy) { loc.language = lang }
                } label: {
                    Text(lang.shortLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selected ? Color.white : Palette.inkSoft)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background {
                            if selected {
                                Capsule().fill(Palette.accentGradient)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.7), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
        .sensoryFeedback(.selection, trigger: loc.language)
    }
}

/// Шапка вкладки: заголовок и кнопка настроек (язык и PIN — в настройках).
struct TopBar: View {
    var subtitle: String?
    var title: String

    @Environment(LocalizationManager.self) private var loc
    @Environment(AppSession.self) private var session

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle {
                    Text(subtitle)
                        .font(.appSubheadline)
                        .foregroundStyle(Palette.inkSoft)
                }
                Text(title)
                    .font(.appTitle(loc.language, size: 30))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            CircleIconButton(systemName: "gearshape.fill") { session.showSettings = true }
                .accessibilityLabel(loc.t(.settings))
        }
        .padding(.top, 4)
    }
}

struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.rose)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.75), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct CardLabel: View {
    let text: String
    var symbol: String?
    var color: Color = Palette.rose

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
        }
        .font(.system(.footnote, design: .rounded).weight(.semibold))
        .foregroundStyle(color)
    }
}

struct CategoryDot: View {
    let category: PlanCategory
    var size: CGFloat = 8

    var body: some View {
        Circle().fill(category.color).frame(width: size, height: size)
    }
}

/// Пилюля категории для выбора в формах.
struct CategoryPicker: View {
    @Binding var selection: PlanCategory
    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
            ForEach(PlanCategory.allCases) { cat in
                let selected = selection == cat
                Button {
                    selection = cat
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: cat.symbol).font(.caption)
                        Text(loc.t(cat.titleKey)).font(.appSubheadline.weight(.semibold))
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selected ? Color.white : Palette.ink)
                    .background(selected ? cat.color : cat.color.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Поле ввода в стиле стеклянной карточки.
struct SoftField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .font(.appBody)
            .lineLimit(axis == .vertical ? 3...8 : 1...1)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.sakura, lineWidth: 1))
    }
}
