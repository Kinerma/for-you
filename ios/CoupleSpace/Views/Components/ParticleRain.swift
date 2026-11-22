import SwiftUI

/// Короткий дождь частиц на TimelineView + Canvas: конфетти для Match,
/// лепестки и сердечки пригодятся для «Отправить поддержку» (модуль 3).
struct ParticleRain: View {
    enum Kind { case confetti, petals, hearts, sparkles }

    var kind: Kind = .confetti
    var count = 70
    var duration: Double = 3.2

    @State private var start = Date()
    @State private var seeds: [Particle] = []

    struct Particle {
        let x: Double        // 0...1 стартовая позиция по горизонтали
        let delay: Double    // задержка старта, сек
        let speed: Double    // доля высоты экрана в секунду
        let sway: Double     // амплитуда покачивания, pt
        let spin: Double     // скорость вращения, рад/сек
        let size: Double
        let colorIndex: Int
    }

    private var colors: [Color] {
        switch kind {
        case .confetti: return [Palette.rose, Palette.lavenderDeep, Palette.walk, Palette.food, Color(hex: 0xF6C453)]
        case .petals: return [Palette.sakura, Color(hex: 0xF4B6C8), Color.white]
        case .hearts: return [Palette.rose, Color(hex: 0xF4B6C8), Palette.lavenderDeep]
        case .sparkles: return [Color(hex: 0xF6C453), Palette.rose, Palette.lavenderDeep, Color.white]
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in seeds {
                    let local = t - p.delay
                    guard local > 0 else { continue }
                    let y = -20 + local * p.speed * size.height
                    guard y < size.height + 30 else { continue }
                    let x = p.x * size.width + sin(local * 2.4 + p.x * 10) * p.sway
                    let fade = max(0, min(1, (duration + 0.8 - local) / 0.8))
                    var layer = ctx
                    layer.opacity = fade
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(local * p.spin))
                    let color = colors[p.colorIndex % colors.count]
                    switch kind {
                    case .confetti:
                        layer.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)),
                                   with: .color(color))
                    case .petals:
                        layer.fill(Path(ellipseIn: CGRect(x: -p.size / 2, y: -p.size / 3, width: p.size, height: p.size * 0.66)),
                                   with: .color(color))
                    case .hearts:
                        layer.draw(Text("♥").font(.system(size: p.size)).foregroundStyle(color), at: .zero)
                    case .sparkles:
                        layer.draw(Text("✦").font(.system(size: p.size)).foregroundStyle(color), at: .zero)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            start = Date()
            seeds = (0..<count).map { i in
                Particle(
                    x: Double.random(in: 0...1),
                    delay: Double(i) / Double(count) * 0.9,
                    speed: Double.random(in: 0.28...0.5),
                    sway: Double.random(in: 8...26),
                    spin: Double.random(in: -4...4),
                    size: Double.random(in: kind == .confetti ? 8...14 : 12...22),
                    colorIndex: i
                )
            }
        }
    }
}
