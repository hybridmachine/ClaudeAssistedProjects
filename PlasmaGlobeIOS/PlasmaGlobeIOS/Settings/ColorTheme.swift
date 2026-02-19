import simd

enum ThemeMode: String, CaseIterable {
    case custom
    case void
    case rainbow
}

struct ColorTheme: Identifiable {
    let id: String
    let name: String
    let coreColorA: SIMD4<Float>
    let coreColorB: SIMD4<Float>
    let glowColorA: SIMD4<Float>
    let glowColorB: SIMD4<Float>
    let shellTint: SIMD4<Float>
    let contactColor: SIMD4<Float>
    let isRainbow: Bool

    init(id: String, name: String,
         coreColorA: SIMD4<Float>, coreColorB: SIMD4<Float>,
         glowColorA: SIMD4<Float>, glowColorB: SIMD4<Float>,
         shellTint: SIMD4<Float>, contactColor: SIMD4<Float>,
         isRainbow: Bool = false) {
        self.id = id
        self.name = name
        self.coreColorA = coreColorA
        self.coreColorB = coreColorB
        self.glowColorA = glowColorA
        self.glowColorB = glowColorB
        self.shellTint = shellTint
        self.contactColor = contactColor
        self.isRainbow = isRainbow
    }

    func toPlasmaConfig(tendrilCount: Int32, brightness: Float, speed: Float, thickness: Float, respawnRate: Float) -> PlasmaConfig {
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
            tendrilThickness: thickness,
            respawnRate: respawnRate,
            rainbowMode: isRainbow ? 1 : 0
        )
    }

    // Preview gradient colors for the theme picker (first two dominant colors)
    var previewColors: (SIMD3<Float>, SIMD3<Float>) {
        (SIMD3<Float>(coreColorA.x, coreColorA.y, coreColorA.z),
         SIMD3<Float>(glowColorB.x, glowColorB.y, glowColorB.z))
    }
}

extension ColorTheme {
    static let allThemes: [ColorTheme] = [void, rainbow]

    /// Derive a full 6-color theme from two user-chosen colors.
    /// T = tendril color, E = endpoint color.
    static func custom(tendrilColor t: SIMD3<Float>, endpointColor e: SIMD3<Float>) -> ColorTheme {
        let white = SIMD3<Float>(1, 1, 1)
        return ColorTheme(
            id: "custom",
            name: "Custom",
            coreColorA: SIMD4<Float>(mix(e, white, t: 0.7), 1.0),
            coreColorB: SIMD4<Float>(mix(t, white, t: 0.5), 1.0),
            glowColorA: SIMD4<Float>(e, 1.0),
            glowColorB: SIMD4<Float>(t, 1.0),
            shellTint:  SIMD4<Float>(t * 0.05, 1.0),
            contactColor: SIMD4<Float>(mix(e, white, t: 0.3), 1.0)
        )
    }

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

    static let rainbow = ColorTheme(
        id: "rainbow",
        name: "Rainbow",
        coreColorA: SIMD4<Float>(0.9, 0.9, 1.0, 1.0),
        coreColorB: SIMD4<Float>(0.85, 0.85, 1.0, 1.0),
        glowColorA: SIMD4<Float>(0.5, 0.3, 0.8, 1.0),
        glowColorB: SIMD4<Float>(0.3, 0.5, 0.9, 1.0),
        shellTint: SIMD4<Float>(0.04, 0.04, 0.08, 1.0),
        contactColor: SIMD4<Float>(0.95, 0.95, 1.0, 1.0),
        isRainbow: true
    )
}
