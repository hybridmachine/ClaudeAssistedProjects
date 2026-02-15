import CoreHaptics
import UIKit

final class HapticManager {
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var isPlaying = false

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
        } catch {
            print("Haptic engine init failed: \(error)")
        }
    }

    func startContinuous() {
        guard let engine = engine, !isPlaying else { return }
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0,
                duration: 30
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
            isPlaying = true
        } catch {
            print("Haptic start failed: \(error)")
        }
    }

    func updateForce(_ force: Float) {
        guard isPlaying else { return }
        let intensity = CHHapticDynamicParameter(
            parameterID: .hapticIntensityControl,
            value: max(0.1, force),
            relativeTime: 0
        )
        let sharpness = CHHapticDynamicParameter(
            parameterID: .hapticSharpnessControl,
            value: force * 0.6,
            relativeTime: 0
        )
        try? continuousPlayer?.sendParameters([intensity, sharpness], atTime: CHHapticTimeImmediate)
    }

    func stop() {
        guard isPlaying else { return }
        try? continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        isPlaying = false
    }

    func playDischargeBurst() {
        guard let engine = engine else { return }
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Haptic burst failed: \(error)")
        }
    }
}
