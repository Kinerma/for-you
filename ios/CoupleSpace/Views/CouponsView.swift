import SwiftUI

/// Вкладка «Сюрпризы»: скретч-купоны желаний (ТЗ v2, 2.3).
struct SurprisesView: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc

    private enum Mode: Hashable { case forMe, fromMe }

    @State private var mode: Mode = .forMe
    @State private var creating = false
    @State private var opened: Coupon?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TopBar(title: loc.t(.coupons))

                Picker("", selection: $mode) {
                    Text(loc.t(.couponsForMe)).tag(Mode.forMe)
                    Text(loc.t(.couponsFromMe)).tag(Mode.fromMe)
                }
                .pickerStyle(.segmented)

                let list = mode == .forMe ? store.coupons(for: session.me) : store.coupons(from: session.me)

                if list.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(list) { coupon in
                            Button { opened = coupon } label: {
                                CouponRow(coupon: coupon, incoming: mode == .forMe)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if coupon.createdBy == session.me && !coupon.isRedeemed {
                                    Button(role: .destructive) { store.delete(coupon) } label: {
                                        Label(loc.t(.delete), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                Button(loc.t(.addCoupon)) { creating = true }
                    .buttonStyle(GradientButtonStyle())
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(WatercolorBackground())
        .sheet(isPresented: $creating) { CouponEditorSheet() }
        .sheet(item: $opened) { coupon in
            CouponDetailSheet(couponId: coupon.id)
                .presentationDetents([.large])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🎟️").font(.system(size: 44))
            Text(mode == .forMe ? loc.t(.couponsEmptyForMe) : loc.t(.couponsEmptyFromMe))
                .font(.appBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 28)
    }
}

// MARK: - Row

struct CouponRow: View {
    let coupon: Coupon
    let incoming: Bool

    @Environment(LocalizationManager.self) private var loc

    /// Пока получатель не стёр слой, содержимое скрыто и для него в списке.
    private var hidden: Bool { incoming && !coupon.isScratched }

    var body: some View {
        HStack(spacing: 14) {
            Text(hidden ? "🎟️" : coupon.emoji)
                .font(.system(size: 34))
                .frame(width: 58, height: 58)
                .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(hidden ? loc.t(.couponHidden) : coupon.title)
                    .font(.appBody.weight(.semibold))
                    .lineLimit(2)
                Text(status)
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(14)
        .background {
            TicketShape()
                .fill(hidden ? AnyShapeStyle(LinearGradient(colors: [Palette.sakura, Palette.lavender], startPoint: .topLeading, endPoint: .bottomTrailing))
                             : AnyShapeStyle(Color.white.opacity(0.75)))
        }
        .overlay { TicketShape().stroke(Color.white.opacity(0.8), lineWidth: 1) }
        .shadow(color: Palette.rose.opacity(0.15), radius: 12, y: 6)
        .opacity(coupon.isRedeemed ? 0.6 : 1)
    }

    private var status: String {
        if coupon.isRedeemed { return loc.t(.couponUsed) }
        if coupon.isScratched { return loc.t(.couponOpened) }
        return incoming ? loc.t(.scratchHint) : loc.t(.couponNotOpened)
    }

    private var statusColor: Color {
        if coupon.isRedeemed { return Palette.inkSoft }
        if coupon.isScratched { return Palette.walk }
        return Palette.rose
    }
}

/// Билет с полукруглыми вырезами по бокам.
struct TicketShape: Shape {
    var radius: CGFloat = 20
    var notch: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        let body = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        var notches = Path()
        notches.addEllipse(in: CGRect(x: rect.minX - notch, y: rect.midY - notch, width: notch * 2, height: notch * 2))
        notches.addEllipse(in: CGRect(x: rect.maxX - notch, y: rect.midY - notch, width: notch * 2, height: notch * 2))
        return body.subtracting(notches)
    }
}

// MARK: - Detail: scratch & redeem

struct CouponDetailSheet: View {
    let couponId: String

    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var confirmRedeem = false
    @State private var redeemTrigger = 0

    /// Берём актуальную версию из стора, чтобы видеть изменения партнёра.
    private var coupon: Coupon? { store.coupons.first { $0.id == couponId } }

    var body: some View {
        NavigationStack {
            ZStack {
                WatercolorBackground()
                if let coupon {
                    content(coupon)
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.done)) { dismiss() }.fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.success, trigger: redeemTrigger)
        }
    }

    @ViewBuilder
    private func content(_ coupon: Coupon) -> some View {
        let incoming = coupon.recipientId == session.me
        let fromName = store.partnerName(coupon.createdBy) ?? loc.t(.partner)
        let toName = store.partnerName(coupon.recipientId) ?? loc.t(.partner)

        VStack(spacing: 22) {
            Text(incoming ? "\(loc.t(.couponFrom)) \(fromName)" : "\(loc.t(.couponFor)) \(toName)")
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(Palette.inkSoft)

            Group {
                if incoming && !coupon.isScratched {
                    ScratchCard(hint: loc.t(.scratchHint), onRevealed: { store.markScratched(coupon) }) {
                        couponFace(coupon)
                    }
                } else {
                    couponFace(coupon)
                }
            }
            .frame(height: 300)
            .clipShape(TicketShape(radius: 28, notch: 14))
            .shadow(color: Palette.rose.opacity(0.25), radius: 20, y: 10)

            if coupon.isRedeemed {
                Label(loc.t(.couponUsed) + (coupon.redeemedAt.map { " · " + loc.formatted($0, template: "dMMMM") } ?? ""),
                      systemImage: "checkmark.seal.fill")
                    .font(.appBody.weight(.semibold))
                    .foregroundStyle(Palette.lavenderDeep)
            } else if incoming && coupon.isScratched {
                Button(loc.t(.couponUse)) { confirmRedeem = true }
                    .buttonStyle(GradientButtonStyle())
            } else if !incoming {
                Text(coupon.isScratched ? loc.t(.couponOpened) : loc.t(.couponNotOpened))
                    .font(.appSubheadline)
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .padding(24)
        .confirmationDialog(loc.t(.couponUse), isPresented: $confirmRedeem, titleVisibility: .visible) {
            Button(loc.t(.couponUse)) {
                store.redeem(coupon)
                redeemTrigger += 1
            }
            Button(loc.t(.cancel), role: .cancel) {}
        } message: {
            Text(loc.t(.couponUseConfirm))
        }
    }

    private func couponFace(_ coupon: Coupon) -> some View {
        ZStack {
            LinearGradient(colors: [Color.white, Palette.champagne], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 12) {
                Text(coupon.emoji).font(.system(size: 64))
                Text(coupon.title)
                    .font(.appTitle(loc.language, size: 24))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink)
                if !coupon.description.isEmpty {
                    Text(coupon.description)
                        .font(.appBody)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .padding(28)

            if coupon.isRedeemed {
                Text(loc.t(.couponUsed).uppercased())
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.rose.opacity(0.75))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.rose.opacity(0.75), lineWidth: 3))
                    .rotationEffect(.degrees(-14))
            }
        }
    }
}

// MARK: - Editor

struct CouponEditorSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    @State private var emoji = "🎁"
    @State private var title = ""
    @State private var details = ""
    @State private var sent = 0

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        CardLabel(text: loc.t(.couponIdeas), symbol: "lightbulb")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Coupon.presets) { preset in
                                    Button {
                                        emoji = preset.emoji
                                        title = preset.title(loc.language)
                                    } label: {
                                        Text("\(preset.emoji) \(preset.title(loc.language))")
                                            .font(.appSubheadline.weight(.semibold))
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(Color.white.opacity(0.75), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(Coupon.emojiChoices, id: \.self) { item in
                            Button { emoji = item } label: {
                                Text(item)
                                    .font(.system(size: 26))
                                    .frame(maxWidth: .infinity, minHeight: 46)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(emoji == item ? Palette.sakura : Color.white.opacity(0.7))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SoftField(placeholder: loc.t(.couponTitle), text: $title)
                    SoftField(placeholder: loc.t(.couponDescription), text: $details, axis: .vertical)
                }
                .padding(20)
            }
            .background(WatercolorBackground())
            .navigationTitle(loc.t(.newCoupon))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.couponGive)) {
                        store.giveCoupon(
                            title: trimmedTitle,
                            description: details.trimmingCharacters(in: .whitespacesAndNewlines),
                            emoji: emoji,
                            from: session.me
                        )
                        sent += 1
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedTitle.isEmpty)
                }
            }
            .sensoryFeedback(.selection, trigger: emoji)
            .sensoryFeedback(.success, trigger: sent)
        }
    }
}
