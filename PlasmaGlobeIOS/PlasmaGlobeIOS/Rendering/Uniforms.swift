import simd

struct Uniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var cameraDistance: Float = 5.0
    var cameraTime: Float = 0.0
    var touchCount: Int32 = 0
    var dischargeTime: Float = -1.0
    var gyroTilt: SIMD2<Float> = .zero
}

struct TouchPoint {
    var position: SIMD2<Float> = .zero
    var force: Float = 0.0
    var active: Float = 0.0
}

let maxTouchSlots = 5

struct BreathingUniforms {
    var isActive: Int32 = 0           // 0 or 1
    var breathingIntensity: Float = 0 // 0=rest, 1=peak inhale
    var breathPhase: Float = 0        // 0..1 within current state
    var breathState: Int32 = 0        // matches BreathState raw values
    var cyclePhase: Float = 0         // 0..1 across full cycle
    var padding: Float = 0            // align to 24 bytes
}

struct PlasmaConfig {
    var coreColorA: SIMD4<Float> = SIMD4<Float>(1.0, 0.7, 0.85, 1.0)
    var coreColorB: SIMD4<Float> = SIMD4<Float>(0.85, 0.85, 1.0, 1.0)
    var glowColorA: SIMD4<Float> = SIMD4<Float>(0.85, 0.25, 0.65, 1.0)
    var glowColorB: SIMD4<Float> = SIMD4<Float>(0.45, 0.25, 0.9, 1.0)
    var shellTint: SIMD4<Float> = SIMD4<Float>(0.04, 0.05, 0.1, 1.0)
    var contactColor: SIMD4<Float> = SIMD4<Float>(0.9, 0.9, 1.0, 1.0)
    var tendrilCount: Int32 = 12
    var brightness: Float = 1.0
    var speed: Float = 1.0
    var tendrilThickness: Float = 1.0
    var respawnRate: Float = 1.0
    var rainbowMode: Int32 = 0
}
