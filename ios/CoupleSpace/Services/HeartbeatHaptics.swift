import CoreHaptics
import UIKit

/// Спокойное сердцебиение на CoreHaptics: двойной мягкий удар раз в секунду (ТЗ v2, 1.2).
final class HeartbeatHaptics {
    static let shared = HeartbeatHaptics()

    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private var oneShot: CHHapticPatternPlayer?
    private let fallback = UIImpactFeedbackGenerator(style: .soft)

    private var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    var isPlaying: Bool { player != nil }

    func start() {
        guard player == nil else { return }
        guard supportsHaptics else {
            fallback.impactOccurred()
            return
        }
        do {
            let engine = try prepareEngine()
            let beat = { (time: TimeInterval, intensity: Float) in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
                    ],
                    relativeTime: time
                )
            }
            // «Тук-тук»: 0.45 → 0.7, пауза до следующей секунды.
            let pattern = try CHHapticPattern(events: [beat(0, 0.45), beat(0.22, 0.7)], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            player.loopEnd = 1.0
            try player.start(atTime: CHHapticTimeImmediate)
            self.player = player
        } catch {
            print("Heartbeat haptics failed:", error.localizedDescription)
        }
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
    }

    /// Нарастающее сердцебиение на время удержания кнопки «Обнять» (~1.5 сек).
    func playRising(duration: TimeInterval = 1.5) {
        playOnce(events: stride(from: 0.0, to: duration, by: 0.5).enumerated().flatMap { i, t in
            let base = Float(0.3 + 0.25 * Double(i))
            return [beatEvent(at: t, intensity: min(base, 1)), beatEvent(at: t + 0.2, intensity: min(base + 0.2, 1))]
        })
    }

    /// Несколько спокойных ударов — когда приходит объятие от партнёра.
    func playBeats(_ count: Int = 4) {
        playOnce(events: (0..<count).flatMap { i in
            let t = Double(i)
            return [beatEvent(at: t, intensity: 0.45), beatEvent(at: t + 0.22, intensity: 0.7)]
        })
    }

    private func beatEvent(at time: TimeInterval, intensity: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
            ],
            relativeTime: time
        )
    }

    private func playOnce(events: [CHHapticEvent]) {
        guard supportsHaptics else { fallback.impactOccurred(); return }
        do {
            let engine = try prepareEngine()
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            oneShot = player
        } catch {
            print("Haptics failed:", error.localizedDescription)
        }
    }

    /// Прервать одноразовый паттерн (палец отпустили раньше времени).
    func cancelOneShot() {
        try? oneShot?.stop(atTime: CHHapticTimeImmediate)
        oneShot = nil
    }

    /// Одиночный мягкий отклик (например, когда начинаешь обнимать один).
    func softTap() {
        fallback.impactOccurred(intensity: 0.6)
    }

    private func prepareEngine() throws -> CHHapticEngine {
        if let engine {
            try engine.start()
            return engine
        }
        let engine = try CHHapticEngine()
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak self] in
            try? self?.engine?.start()
        }
        engine.stoppedHandler = { [weak self] _ in
            self?.player = nil
        }
        try engine.start()
        self.engine = engine
        return engine
    }
}
