import Foundation
import QuartzCore
import Combine

enum BreathState: Int {
    case idle = 0
    case inhale = 1
    case hold = 2
    case exhale = 3
    case holdAfterExhale = 4
}

final class BreathingEngine: ObservableObject {
    @Published var currentState: BreathState = .idle
    @Published var breathPhase: Float = 0       // 0..1 within current state
    @Published var cyclePhase: Float = 0        // 0..1 across full cycle
    @Published var isActive: Bool = false
    @Published var remainingTime: TimeInterval = 0

    var breathingIntensity: Float {
        switch currentState {
        case .idle: return 0
        case .inhale: return breathPhase
        case .hold: return 1.0
        case .exhale: return 1.0 - breathPhase
        case .holdAfterExhale: return 0.0
        }
    }

    private(set) var previousState: BreathState = .idle

    private var displayLink: CADisplayLink?
    private var durations = BreathingDurations(inhale: 4, hold: 4, exhale: 4, holdAfterExhale: 4)
    private var sessionMinutes: Int = 0
    private var sessionStartTime: CFAbsoluteTime = 0
    private var stateStartTime: CFAbsoluteTime = 0
    private var currentStateDuration: TimeInterval = 0

    func start(pattern: BreathingPattern, customDurations: BreathingDurations? = nil, sessionMinutes: Int = 5) {
        stop()

        if pattern == .custom, let custom = customDurations {
            durations = custom
        } else {
            durations = pattern.defaultDurations
        }

        self.sessionMinutes = sessionMinutes
        sessionStartTime = CFAbsoluteTimeGetCurrent()

        if sessionMinutes > 0 {
            remainingTime = TimeInterval(sessionMinutes * 60)
        } else {
            remainingTime = 0
        }

        previousState = .idle
        transitionTo(.inhale)
        isActive = true

        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isActive = false
        currentState = .idle
        breathPhase = 0
        cyclePhase = 0
        remainingTime = 0
    }

    @objc private func tick() {
        let now = CFAbsoluteTimeGetCurrent()

        // Session timer
        if sessionMinutes > 0 {
            let elapsed = now - sessionStartTime
            let total = TimeInterval(sessionMinutes * 60)
            remainingTime = max(0, total - elapsed)
            if remainingTime <= 0 {
                stop()
                return
            }
        }

        guard currentState != .idle else { return }

        let stateElapsed = now - stateStartTime

        if currentStateDuration > 0 {
            breathPhase = Float(min(stateElapsed / currentStateDuration, 1.0))
        } else {
            breathPhase = 1.0
        }

        // Update cycle phase
        updateCyclePhase(stateElapsed: stateElapsed)

        // Check for state transition
        if stateElapsed >= currentStateDuration {
            advanceState()
        }
    }

    private func updateCyclePhase(stateElapsed: TimeInterval) {
        let total = durations.totalCycleDuration
        guard total > 0 else { cyclePhase = 0; return }

        var elapsed: TimeInterval = 0
        switch currentState {
        case .idle: break
        case .inhale: elapsed = stateElapsed
        case .hold: elapsed = durations.inhale + stateElapsed
        case .exhale: elapsed = durations.inhale + durations.hold + stateElapsed
        case .holdAfterExhale: elapsed = durations.inhale + durations.hold + durations.exhale + stateElapsed
        }
        cyclePhase = Float(min(elapsed / total, 1.0))
    }

    private func advanceState() {
        let nextState: BreathState
        switch currentState {
        case .idle: return
        case .inhale: nextState = .hold
        case .hold: nextState = .exhale
        case .exhale: nextState = .holdAfterExhale
        case .holdAfterExhale: nextState = .inhale
        }
        transitionTo(nextState)
    }

    private func transitionTo(_ state: BreathState) {
        let duration = durationFor(state)

        // Auto-skip zero-duration states
        if duration <= 0 && state != .idle {
            previousState = currentState
            currentState = state
            // Advance again immediately
            advanceState()
            return
        }

        previousState = currentState
        currentState = state
        currentStateDuration = duration
        stateStartTime = CFAbsoluteTimeGetCurrent()
        breathPhase = 0
    }

    private func durationFor(_ state: BreathState) -> TimeInterval {
        switch state {
        case .idle: return 0
        case .inhale: return durations.inhale
        case .hold: return durations.hold
        case .exhale: return durations.exhale
        case .holdAfterExhale: return durations.holdAfterExhale
        }
    }
}
