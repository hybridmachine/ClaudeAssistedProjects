import simd

struct Uniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var touchPosition: SIMD2<Float>
    var touchActive: Float
    var cameraDistance: Float = 5.0
}
