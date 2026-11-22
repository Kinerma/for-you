import SwiftUI

/// Пастельный «защитный слой», который стирают пальцем.
/// Когда стёрто больше `threshold` площади, слой плавно исчезает и вызывается `onRevealed`.
struct ScratchCard<Content: View>: View {
    var threshold: Double = 0.55
    var brushRadius: CGFloat = 24
    var hint: String
    var onRevealed: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var points: [CGPoint] = []
    @State private var scratchedCells = Set<Int>()
    @State private var revealed = false
    @State private var revealTrigger = 0
    @State private var scratchTick = 0

    private let columns = 16
    private let rows = 10

    var body: some View {
        GeometryReader { geo in
            ZStack {
                content()
                    .frame(width: geo.size.width, height: geo.size.height)

                if !revealed {
                    cover(size: geo.size)
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in scratch(at: value.location, in: geo.size) }
            )
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: scratchTick)
        .sensoryFeedback(.success, trigger: revealTrigger)
    }

    private func cover(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [Palette.sakura, Palette.lavender, Palette.champagne]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
                )
            )
            // Мелкие блёстки, чтобы слой выглядел как «защитное покрытие».
            for i in 0..<36 {
                let x = CGFloat((i * 73) % 100) / 100 * canvasSize.width
                let y = CGFloat((i * 37 + 11) % 100) / 100 * canvasSize.height
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 3, height: 3)), with: .color(.white.opacity(0.7)))
            }
            ctx.draw(
                Text("✨ " + hint)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.7)),
                at: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            )

            ctx.blendMode = .destinationOut
            for point in points {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: point.x - brushRadius, y: point.y - brushRadius,
                                           width: brushRadius * 2, height: brushRadius * 2)),
                    with: .color(.black)
                )
            }
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }

    private func scratch(at point: CGPoint, in size: CGSize) {
        guard !revealed, size.width > 0, size.height > 0 else { return }
        if let last = points.last {
            // Заполняем промежутки, чтобы быстрый жест не оставлял дырявый след.
            let distance = hypot(point.x - last.x, point.y - last.y)
            let steps = Int(distance / (brushRadius / 2))
            if steps > 1 {
                for s in 1..<steps {
                    let t = CGFloat(s) / CGFloat(steps)
                    points.append(CGPoint(x: last.x + (point.x - last.x) * t, y: last.y + (point.y - last.y) * t))
                }
            }
        }
        points.append(point)
        markCells(around: point, in: size)

        if points.count % 12 == 0 { scratchTick += 1 }

        let progress = Double(scratchedCells.count) / Double(columns * rows)
        if progress >= threshold {
            withAnimation(.easeOut(duration: 0.6)) { revealed = true }
            revealTrigger += 1
            onRevealed()
        }
    }

    private func markCells(around point: CGPoint, in size: CGSize) {
        let cellW = size.width / CGFloat(columns)
        let cellH = size.height / CGFloat(rows)
        for row in 0..<rows {
            for col in 0..<columns {
                let center = CGPoint(x: (CGFloat(col) + 0.5) * cellW, y: (CGFloat(row) + 0.5) * cellH)
                if hypot(center.x - point.x, center.y - point.y) <= brushRadius {
                    scratchedCells.insert(row * columns + col)
                }
            }
        }
    }
}
