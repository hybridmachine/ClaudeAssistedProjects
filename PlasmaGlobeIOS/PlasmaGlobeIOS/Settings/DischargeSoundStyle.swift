import Foundation

enum DischargeSoundStyle: String, CaseIterable, Identifiable {
    case crackle = "crackle"
    case crystallineChime = "crystalline_chime"
    case harmonicShimmer = "harmonic_shimmer"
    case singingBowl = "singing_bowl"
    case electricArcSweep = "electric_arc_sweep"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .crackle: return "Crackle"
        case .crystallineChime: return "Crystalline Chime"
        case .harmonicShimmer: return "Harmonic Shimmer"
        case .singingBowl: return "Singing Bowl"
        case .electricArcSweep: return "Electric Arc Sweep"
        }
    }

    var intValue: Int {
        switch self {
        case .crackle: return 0
        case .crystallineChime: return 1
        case .harmonicShimmer: return 2
        case .singingBowl: return 3
        case .electricArcSweep: return 4
        }
    }

    static func from(intValue: Int) -> DischargeSoundStyle {
        allCases.first { $0.intValue == intValue } ?? .crystallineChime
    }

    static func from(id: String) -> DischargeSoundStyle {
        DischargeSoundStyle(rawValue: id) ?? .crystallineChime
    }

    var synthesizer: any DischargeSoundSynthesizer {
        switch self {
        case .crackle: return CrackleSynthesizer()
        case .crystallineChime: return CrystallineChimeSynthesizer()
        case .harmonicShimmer: return HarmonicShimmerSynthesizer()
        case .singingBowl: return SingingBowlSynthesizer()
        case .electricArcSweep: return ElectricArcSweepSynthesizer()
        }
    }
}
