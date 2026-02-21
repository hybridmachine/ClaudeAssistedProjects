import Foundation

struct BreathingDurations {
    var inhale: TimeInterval
    var hold: TimeInterval
    var exhale: TimeInterval
    var holdAfterExhale: TimeInterval

    var totalCycleDuration: TimeInterval {
        inhale + hold + exhale + holdAfterExhale
    }
}

enum BreathingPattern: String, CaseIterable, Identifiable {
    case boxBreathing = "box"
    case relaxation478 = "478"
    case calmBreathing = "calm"
    case custom = "custom"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .boxBreathing: return "Box Breathing"
        case .relaxation478: return "4-7-8 Relaxation"
        case .calmBreathing: return "Calm Breathing"
        case .custom: return "Custom"
        }
    }

    var defaultDurations: BreathingDurations {
        switch self {
        case .boxBreathing:
            return BreathingDurations(inhale: 4, hold: 4, exhale: 4, holdAfterExhale: 4)
        case .relaxation478:
            return BreathingDurations(inhale: 4, hold: 7, exhale: 8, holdAfterExhale: 0)
        case .calmBreathing:
            return BreathingDurations(inhale: 4, hold: 0, exhale: 6, holdAfterExhale: 0)
        case .custom:
            return BreathingDurations(inhale: 4, hold: 4, exhale: 4, holdAfterExhale: 4)
        }
    }
}

enum SessionDuration: Int, CaseIterable, Identifiable {
    case oneMinute = 1
    case threeMinutes = 3
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case twentyMinutes = 20
    case unlimited = 0

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .unlimited: return "Unlimited"
        default: return "\(rawValue) min"
        }
    }
}
