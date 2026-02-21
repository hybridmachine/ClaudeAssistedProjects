import SwiftUI
import Combine

final class PlasmaSettings: ObservableObject {
    @AppStorage("themeMode") var themeMode: String = "custom"
    @AppStorage("customTendrilR") var customTendrilR: Double = 0.85
    @AppStorage("customTendrilG") var customTendrilG: Double = 0.25
    @AppStorage("customTendrilB") var customTendrilB: Double = 0.65
    @AppStorage("customEndpointR") var customEndpointR: Double = 0.45
    @AppStorage("customEndpointG") var customEndpointG: Double = 0.25
    @AppStorage("customEndpointB") var customEndpointB: Double = 0.90
    @AppStorage("tendrilCount") var tendrilCount: Double = 12
    @AppStorage("brightness") var brightness: Double = 1.0
    @AppStorage("speed") var speed: Double = 1.0
    @AppStorage("tendrilThickness") var tendrilThickness: Double = 1.0
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @AppStorage("soundVolume") var soundVolume: Double = 0.5
    @AppStorage("dischargeSoundStyle") var dischargeSoundStyleId: String = "crystalline_chime"
    @AppStorage("humFrequency") var humFrequency: Double = 60.0
    @AppStorage("tiltEnabled") var tiltEnabled: Bool = true
    @AppStorage("respawnRate") var respawnRate: Double = 1.0
    @AppStorage("preferredFPS") var preferredFPS: Int = 60

    // Breathing / Meditation
    @AppStorage("breathingPatternId") var breathingPatternId: String = "box"
    @AppStorage("breathingSessionMinutes") var breathingSessionMinutes: Int = 5
    @AppStorage("breathingChimeEnabled") var breathingChimeEnabled: Bool = true
    @AppStorage("customInhaleDuration") var customInhaleDuration: Double = 4.0
    @AppStorage("customHoldDuration") var customHoldDuration: Double = 4.0
    @AppStorage("customExhaleDuration") var customExhaleDuration: Double = 4.0
    @AppStorage("customHoldAfterExhaleDuration") var customHoldAfterExhaleDuration: Double = 4.0

    init() {
        // One-time migration from old selectedThemeId
        let defaults = UserDefaults.standard
        if let oldId = defaults.string(forKey: "selectedThemeId") {
            switch oldId {
            case "void":
                defaults.set("void", forKey: "themeMode")
            case "rainbow":
                defaults.set("rainbow", forKey: "themeMode")
            default:
                defaults.set("custom", forKey: "themeMode")
            }
            defaults.removeObject(forKey: "selectedThemeId")
        }
    }

    var dischargeSoundStyle: DischargeSoundStyle {
        DischargeSoundStyle.from(id: dischargeSoundStyleId)
    }

    var customTendrilSIMD: SIMD3<Float> {
        SIMD3<Float>(Float(customTendrilR), Float(customTendrilG), Float(customTendrilB))
    }

    var customEndpointSIMD: SIMD3<Float> {
        SIMD3<Float>(Float(customEndpointR), Float(customEndpointG), Float(customEndpointB))
    }

    var customTendrilColor: Color {
        get {
            Color(red: customTendrilR, green: customTendrilG, blue: customTendrilB)
        }
        set {
            let (r, g, b) = extractRGB(from: newValue)
            customTendrilR = r
            customTendrilG = g
            customTendrilB = b
        }
    }

    var customEndpointColor: Color {
        get {
            Color(red: customEndpointR, green: customEndpointG, blue: customEndpointB)
        }
        set {
            let (r, g, b) = extractRGB(from: newValue)
            customEndpointR = r
            customEndpointG = g
            customEndpointB = b
        }
    }

    var selectedTheme: ColorTheme {
        switch ThemeMode(rawValue: themeMode) ?? .custom {
        case .custom:
            return .custom(tendrilColor: customTendrilSIMD, endpointColor: customEndpointSIMD)
        case .void:
            return .void
        case .rainbow:
            return .rainbow
        }
    }

    var breathingPattern: BreathingPattern {
        BreathingPattern(rawValue: breathingPatternId) ?? .boxBreathing
    }

    var sessionDuration: SessionDuration {
        SessionDuration(rawValue: breathingSessionMinutes) ?? .fiveMinutes
    }

    var customBreathingDurations: BreathingDurations {
        BreathingDurations(
            inhale: customInhaleDuration,
            hold: customHoldDuration,
            exhale: customExhaleDuration,
            holdAfterExhale: customHoldAfterExhaleDuration
        )
    }

    func buildPlasmaConfig() -> PlasmaConfig {
        selectedTheme.toPlasmaConfig(
            tendrilCount: Int32(tendrilCount),
            brightness: Float(brightness),
            speed: Float(speed),
            thickness: Float(tendrilThickness),
            respawnRate: Float(respawnRate)
        )
    }

    /// Extract sRGB components from a SwiftUI Color, clamping P3 gamut values to [0,1].
    private func extractRGB(from color: Color) -> (Double, Double, Double) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (min(max(Double(r), 0), 1),
                min(max(Double(g), 0), 1),
                min(max(Double(b), 0), 1))
    }
}
