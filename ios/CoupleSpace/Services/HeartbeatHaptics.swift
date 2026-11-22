import CoreHaptics
import UIKit

/// Спокойное сердцебиение на CoreHaptics: двойной мягкий удар раз в секунду (ТЗ v2, 1.2).
final class HeartbeatHaptics {
    static let shared = HeartbeatHaptics()

    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
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
