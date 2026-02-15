import simd

struct ColorTheme: Identifiable {
    let id: String
    let name: String
    let coreColorA: SIMD4<Float>
    let coreColorB: SIMD4<Float>
    let glowColorA: SIMD4<Float>
    let glowColorB: SIMD4<Float>
    let shellTint: SIMD4<Float>
    let contactColor: SIMD4<Float>

    func toPlasmaConfig(tendrilCount: Int32, brightness: Float, speed: Float, thickness: Float) -> PlasmaConfig {
        PlasmaConfig(
            coreColorA: coreColorA,
            coreColorB: coreColorB,
            glowColorA: glowColorA,
            glowColorB: glowColorB,
            shellTint: shellTint,
            contactColor: contactColor,
            tendrilCount: tendrilCount,
            brightness: brightness,
            speed: speed,
            tendrilThickness: thickness
        )
    }

    // Preview gradient colors for the theme picker (first two dominant colors)
    var previewColors: (SIMD3<Float>, SIMD3<Float>) {
        (SIMD3<Float>(coreColorA.x, coreColorA.y, coreColorA.z),
         SIMD3<Float>(glowColorB.x, glowColorB.y, glowColorB.z))
    }
}

extension ColorTheme {
    static let allThemes: [ColorTheme] = [
        classicPink, classicPurple, electricGreen, fieryRed, iceBlue, solarFlare, void
    ]

    static let classicPink = ColorTheme(
        id: "classic_pink",
        name: "Classic Pink",
        coreColorA: SIMD4<Float>(1.0, 0.7, 0.85, 1.0),
        coreColorB: SIMD4<Float>(0.85, 0.85, 1.0, 1.0),
        glowColorA: SIMD4<Float>(0.85, 0.25, 0.65, 1.0),
        glowColorB: SIMD4<Float>(0.45, 0.25, 0.9, 1.0),
        shellTint: SIMD4<Float>(0.04, 0.05, 0.1, 1.0),
        contactColor: SIMD4<Float>(0.9, 0.9, 1.0, 1.0)
    )

    static let classicPurple = ColorTheme(
        id: "classic_purple",
        name: "Classic Purple",
        coreColorA: SIMD4<Float>(0.8, 0.6, 1.0, 1.0),
        coreColorB: SIMD4<Float>(0.7, 0.7, 1.0, 1.0),
        glowColorA: SIMD4<Float>(0.6, 0.15, 0.9, 1.0),
        glowColorB: SIMD4<Float>(0.3, 0.1, 0.8, 1.0),
        shellTint: SIMD4<Float>(0.05, 0.03, 0.12, 1.0),
        contactColor: SIMD4<Float>(0.8, 0.7, 1.0, 1.0)
    )

    static let electricGreen = ColorTheme(
        id: "electric_green",
        name: "Electric Green",
        coreColorA: SIMD4<Float>(0.7, 1.0, 0.8, 1.0),
        coreColorB: SIMD4<Float>(0.85, 1.0, 0.9, 1.0),
        glowColorA: SIMD4<Float>(0.2, 0.9, 0.4, 1.0),
        glowColorB: SIMD4<Float>(0.1, 0.6, 0.3, 1.0),
        shellTint: SIMD4<Float>(0.02, 0.08, 0.04, 1.0),
        contactColor: SIMD4<Float>(0.8, 1.0, 0.9, 1.0)
    )

    static let fieryRed = ColorTheme(
        id: "fiery_red",
        name: "Fiery Red",
        coreColorA: SIMD4<Float>(1.0, 0.85, 0.6, 1.0),
        coreColorB: SIMD4<Float>(1.0, 0.95, 0.8, 1.0),
        glowColorA: SIMD4<Float>(1.0, 0.25, 0.1, 1.0),
        glowColorB: SIMD4<Float>(0.8, 0.15, 0.05, 1.0),
        shellTint: SIMD4<Float>(0.1, 0.03, 0.02, 1.0),
        contactColor: SIMD4<Float>(1.0, 0.9, 0.7, 1.0)
    )

    static let iceBlue = ColorTheme(
        id: "ice_blue",
        name: "Ice Blue",
        coreColorA: SIMD4<Float>(0.8, 0.95, 1.0, 1.0),
        coreColorB: SIMD4<Float>(0.9, 0.95, 1.0, 1.0),
        glowColorA: SIMD4<Float>(0.2, 0.5, 1.0, 1.0),
        glowColorB: SIMD4<Float>(0.1, 0.3, 0.9, 1.0),
        shellTint: SIMD4<Float>(0.03, 0.06, 0.12, 1.0),
        contactColor: SIMD4<Float>(0.85, 0.95, 1.0, 1.0)
    )

    static let solarFlare = ColorTheme(
        id: "solar_flare",
        name: "Solar Flare",
        coreColorA: SIMD4<Float>(1.0, 1.0, 0.7, 1.0),
        coreColorB: SIMD4<Float>(1.0, 0.95, 0.85, 1.0),
        glowColorA: SIMD4<Float>(1.0, 0.6, 0.1, 1.0),
        glowColorB: SIMD4<Float>(0.9, 0.3, 0.05, 1.0),
        shellTint: SIMD4<Float>(0.08, 0.05, 0.02, 1.0),
        contactColor: SIMD4<Float>(1.0, 1.0, 0.8, 1.0)
    )

    static let void = ColorTheme(
        id: "void",
        name: "Void",
        coreColorA: SIMD4<Float>(0.6, 0.6, 0.7, 1.0),
        coreColorB: SIMD4<Float>(0.5, 0.5, 0.55, 1.0),
        glowColorA: SIMD4<Float>(0.15, 0.15, 0.25, 1.0),
        glowColorB: SIMD4<Float>(0.08, 0.08, 0.15, 1.0),
        shellTint: SIMD4<Float>(0.03, 0.03, 0.05, 1.0),
        contactColor: SIMD4<Float>(0.7, 0.7, 0.8, 1.0)
    )
}
