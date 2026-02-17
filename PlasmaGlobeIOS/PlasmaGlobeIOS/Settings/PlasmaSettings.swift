import SwiftUI
import Combine

final class PlasmaSettings: ObservableObject {
    @AppStorage("selectedThemeId") var selectedThemeId: String = "classic_pink"
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

    var dischargeSoundStyle: DischargeSoundStyle {
        DischargeSoundStyle.from(id: dischargeSoundStyleId)
    }

    var selectedTheme: ColorTheme {
        ColorTheme.allThemes.first { $0.id == selectedThemeId } ?? .classicPink
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
}
