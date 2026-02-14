import MetalKit

final class PlasmaRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let starfieldPipeline: MTLRenderPipelineState
    private let plasmaPipeline: MTLRenderPipelineState
    private let noiseTexture: MTLTexture
    private let startTime: CFAbsoluteTime
    private weak var touchHandler: TouchHandler?
    private var cameraTime: Float = 0
    private var lastFrameTime: CFAbsoluteTime?

    init?(mtkView: MTKView, touchHandler: TouchHandler) {
        guard let device = mtkView.device,
              let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.touchHandler = touchHandler
        self.startTime = CFAbsoluteTimeGetCurrent()

        // Create starfield pipeline
        let starfieldDesc = MTLRenderPipelineDescriptor()
        starfieldDesc.vertexFunction = library.makeFunction(name: "fullscreenQuadVertex")
        starfieldDesc.fragmentFunction = library.makeFunction(name: "starfieldFragment")
        starfieldDesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat

        // Create plasma pipeline with alpha blending
        let plasmaDesc = MTLRenderPipelineDescriptor()
        plasmaDesc.vertexFunction = library.makeFunction(name: "fullscreenQuadVertex")
        plasmaDesc.fragmentFunction = library.makeFunction(name: "plasmaGlobeFragment")
        plasmaDesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        plasmaDesc.colorAttachments[0].isBlendingEnabled = true
        plasmaDesc.colorAttachments[0].rgbBlendOperation = .add
        plasmaDesc.colorAttachments[0].alphaBlendOperation = .add
        plasmaDesc.colorAttachments[0].sourceRGBBlendFactor = .one
        plasmaDesc.colorAttachments[0].destinationRGBBlendFactor = .one
        plasmaDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        plasmaDesc.colorAttachments[0].destinationAlphaBlendFactor = .zero

        do {
            self.starfieldPipeline = try device.makeRenderPipelineState(descriptor: starfieldDesc)
            self.plasmaPipeline = try device.makeRenderPipelineState(descriptor: plasmaDesc)
        } catch {
            print("Failed to create pipeline states: \(error)")
            return nil
        }

        // Generate noise texture
        self.noiseTexture = PlasmaRenderer.makeNoiseTexture(device: device)

        super.init()
    }

    private static func makeNoiseTexture(device: MTLDevice) -> MTLTexture {
        let size = 256
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        descriptor.usage = .shaderRead

        let texture = device.makeTexture(descriptor: descriptor)!
        var pixels = [UInt8](repeating: 0, count: size * size)
        for i in 0..<pixels.count {
            pixels[i] = UInt8.random(in: 0...255)
        }
        texture.replace(
            region: MTLRegionMake2D(0, 0, size, size),
            mipmapLevel: 0,
            withBytes: &pixels,
            bytesPerRow: size
        )
        return texture
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let handler = touchHandler, handler.isActive else { return }
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let time = Float(now - startTime)
        let resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))

        // Advance camera orbit only when not touching
        if let last = lastFrameTime, !handler.isTouching {
            cameraTime += Float(now - last)
        }
        lastFrameTime = now

        // Compute default camera distance for ~70% screen width on first frame
        if handler.cameraDistance <= 0 {
            let aspect = resolution.x / resolution.y
            let fov: Float = 1.6
            let targetHalf: Float = 0.35 * aspect // half of 70% screen width in UV
            handler.cameraDistance = sqrt((fov / targetHalf) * (fov / targetHalf) + 1.0)
        }

        var uniforms = Uniforms(
            time: time,
            resolution: resolution,
            touchPosition: handler.touchPosition,
            touchActive: handler.isTouching ? 1.0 : 0.0,
            cameraDistance: handler.cameraDistance,
            cameraTime: cameraTime
        )

        // Pass 1: Starfield
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.005, green: 0.005, blue: 0.015, alpha: 1.0)
        descriptor.colorAttachments[0].storeAction = .store

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.setRenderPipelineState(starfieldPipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }

        // Pass 2: Plasma globe (additive blend over starfield)
        descriptor.colorAttachments[0].loadAction = .load
        descriptor.colorAttachments[0].storeAction = .store

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.setRenderPipelineState(plasmaPipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentTexture(noiseTexture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
