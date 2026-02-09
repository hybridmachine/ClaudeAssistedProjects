import simd

struct Uniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var touchPosition: SIMD2<Float>
    var touchActive: Float
    var padding: Float = 0 // Align to 16-byte boundary
}
