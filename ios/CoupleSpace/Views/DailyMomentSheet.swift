import SwiftUI
import PhotosUI
import UIKit

/// Сжатие и декодирование картинки «момента дня».
/// Пока храним сжатый JPEG прямо в Firestore (base64, ~50–150 КБ); поле imageUrl оставлено под Firebase Storage.
enum MomentImage {
    static func encode(_ image: UIImage, maxSide: CGFloat = 640, quality: CGFloat = 0.6) -> String? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)?.base64EncodedString()
    }

    static func decode(_ base64: String) -> UIImage? {
        guard !base64.isEmpty, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

/// Sheet «Момент дня»: фото из галереи или мини-скетч пальцем + подпись.
struct DailyMomentSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(RoomStore.self) private var store
    @Environment(LocalizationManager.self) private var loc
    @Environment(\.dismiss) private var dismiss

    private enum Mode: Hashable { case photo, sketch }

    @State private var mode: Mode = .photo
    @State private var pickerItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var strokes: [SketchStroke] = []
    @State private var caption = ""
    @State private var sent = 0

    private var canSend: Bool {
        mode == .photo ? photo != nil : !strokes.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("", selection: $mode) {
                        Text(loc.t(.momentPhoto)).tag(Mode.photo)
                        Text(loc.t(.momentSketch)).tag(Mode.sketch)
                    }
                    .pickerStyle(.segmented)

                    switch mode {
                    case .photo: photoPane
                    case .sketch: SketchPad(strokes: $strokes)
                    }

                    SoftField(placeholder: loc.t(.momentCaption), text: $caption)
                        .onChange(of: caption) { _, value in
                            if value.count > 60 { caption = String(value.prefix(60)) }
                        }
                }
                .padding(20)
            }
            .scrollDisabled(mode == .sketch)
            .background(WatercolorBackground())
            .navigationTitle(loc.t(.momentTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc.t(.quizSend), action: send)
                        .fontWeight(.semibold)
                        .disabled(!canSend)
                }
            }
            .sensoryFeedback(.success, trigger: sent)
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item, let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await MainActor.run { photo = image }
            }
        }
    }

    private var photoPane: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.7))
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .frame(height: 300)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(loc.t(.momentPick), systemImage: "photo")
            }
            .buttonStyle(SoftButtonStyle())
        }
    }

    private func send() {
        let image: UIImage?
        let type: DailyMoment.Kind
        switch mode {
        case .photo:
            image = photo
            type = .photo
        case .sketch:
            let renderer = ImageRenderer(content: SketchRender(strokes: strokes).frame(width: 320, height: 320))
            renderer.scale = 2
            image = renderer.uiImage
            type = .sketch
        }
        guard let image, let base64 = MomentImage.encode(image) else { return }
        store.setDailyMoment(type: type, imageBase64: base64,
                             caption: caption.trimmingCharacters(in: .whitespacesAndNewlines), by: session.me)
        sent += 1
        dismiss()
    }
}

// MARK: - Sketch

struct SketchStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var width: CGFloat
    var isEraser: Bool
}

/// Отрисовка штрихов на белом фоне (используется и на экране, и для экспорта картинки).
struct SketchRender: View {
    let strokes: [SketchStroke]

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            for stroke in strokes {
                var path = Path()
                guard let first = stroke.points.first else { continue }
                path.move(to: first)
                if stroke.points.count == 1 {
                    path.addEllipse(in: CGRect(x: first.x - stroke.width / 2, y: first.y - stroke.width / 2,
                                               width: stroke.width, height: stroke.width))
                    ctx.fill(path, with: .color(stroke.isEraser ? .white : stroke.color))
                    continue
                }
                for point in stroke.points.dropFirst() { path.addLine(to: point) }
                ctx.stroke(path, with: .color(stroke.isEraser ? .white : stroke.color),
                           style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// Мини-холст: 5 пастельных цветов, 3 толщины, ластик, отмена и очистка.
struct SketchPad: View {
    @Binding var strokes: [SketchStroke]

    @Environment(LocalizationManager.self) private var loc

    @State private var color: Color = Palette.rose
    @State private var width: CGFloat = 6
    @State private var eraser = false

    private let colors: [Color] = [Palette.rose, Palette.lavenderDeep, Palette.ink, Color(hex: 0xF2B880), Palette.walk]
    private let widths: [CGFloat] = [3, 6, 12]

    var body: some View {
        VStack(spacing: 12) {
            SketchRender(strokes: strokes)
                .frame(width: 320, height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.sakura, lineWidth: 1.5))
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            let point = CGPoint(x: min(max(value.location.x, 0), 320), y: min(max(value.location.y, 0), 320))
                            if value.startLocation != lastStart || strokes.isEmpty {
                                lastStart = value.startLocation
                                strokes.append(SketchStroke(points: [point], color: color,
                                                            width: eraser ? width * 2.5 : width, isEraser: eraser))
                            } else {
                                strokes[strokes.count - 1].points.append(point)
                            }
                        }
                )
                .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                    Circle()
                        .fill(c)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                        .overlay(Circle().strokeBorder(!eraser && color == c ? Palette.ink : .clear, lineWidth: 1.5).padding(-3))
                        .onTapGesture { color = c; eraser = false }
                }
                Spacer(minLength: 4)
                Button { eraser.toggle() } label: {
                    Image(systemName: "eraser.fill")
                        .foregroundStyle(eraser ? Color.white : Palette.ink)
                        .frame(width: 34, height: 34)
                        .background(eraser ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Color.white.opacity(0.75)), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(loc.t(.eraser))
            }

            HStack(spacing: 10) {
                ForEach(widths, id: \.self) { w in
                    Button { width = w } label: {
                        Circle()
                            .fill(Palette.ink)
                            .frame(width: w + 4, height: w + 4)
                            .frame(width: 34, height: 34)
                            .background(width == w ? Palette.sakura : Color.white.opacity(0.75), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button(loc.t(.undo)) { if !strokes.isEmpty { strokes.removeLast() } }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(strokes.isEmpty)
                Button(loc.t(.clear)) { strokes.removeAll() }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(strokes.isEmpty)
            }
        }
    }

    @State private var lastStart: CGPoint = .init(x: -1, y: -1)
}
