import MetalKit
import Combine

final class PlasmaRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let starfieldPipeline: MTLRenderPipelineState
    private let plasmaPipeline: MTLRenderPipelineState
    private let compositePipeline: MTLRenderPipelineState
    private let noiseTexture: MTLTexture
    private let startTime: CFAbsoluteTime
    private weak var touchHandler: TouchHandler?
    private var cameraTime: Float = 0
    private var lastFrameTime: CFAbsoluteTime?
    private var offscreenTexture: MTLTexture?

    private var dischargeStartTime: CFAbsoluteTime?
    private static let dischargeDuration: CFTimeInterval = 1.5

    var plasmaConfig = PlasmaConfig()
    var motionManager: MotionManager?

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

        let starfieldDesc = Self.makeBasePipelineDescriptor(
            library: library, fragmentFunction: "starfieldFragment", pixelFormat: mtkView.colorPixelFormat
        )

        // Plasma renders to half-res rgba16Float offscreen texture
        let plasmaDesc = Self.makeBasePipelineDescriptor(
            library: library, fragmentFunction: "plasmaGlobeFragment", pixelFormat: .rgba16Float
        )

        // Composite pass: additively blends offscreen plasma onto the starfield drawable
        let compositeDesc = Self.makeBasePipelineDescriptor(
            library: library, fragmentFunction: "compositeFragment", pixelFormat: mtkView.colorPixelFormat
        )
        compositeDesc.colorAttachments[0].isBlendingEnabled = true
        compositeDesc.colorAttachments[0].rgbBlendOperation = .add
        compositeDesc.colorAttachments[0].alphaBlendOperation = .add
        compositeDesc.colorAttachments[0].sourceRGBBlendFactor = .one
        compositeDesc.colorAttachments[0].destinationRGBBlendFactor = .one
        compositeDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
        compositeDesc.colorAttachments[0].destinationAlphaBlendFactor = .zero

        do {
            self.starfieldPipeline = try device.makeRenderPipelineState(descriptor: starfieldDesc)
            self.plasmaPipeline = try device.makeRenderPipelineState(descriptor: plasmaDesc)
            self.compositePipeline = try device.makeRenderPipelineState(descriptor: compositeDesc)
        } catch {
            print("Failed to create pipeline states: \(error)")
            return nil
        }

        self.noiseTexture = PlasmaRenderer.makeNoiseTexture(device: device)

        super.init()
    }

    private static func makeBasePipelineDescriptor(
        library: MTLLibrary, fragmentFunction: String, pixelFormat: MTLPixelFormat
    ) -> MTLRenderPipelineDescriptor {
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "fullscreenQuadVertex")
        desc.fragmentFunction = library.makeFunction(name: fragmentFunction)
        desc.colorAttachments[0].pixelFormat = pixelFormat
        return desc
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

    private func ensureOffscreenTexture(drawableSize: CGSize) {
        let w = max(Int(drawableSize.width * 0.5), 1)
        let h = max(Int(drawableSize.height * 0.5), 1)
        if let existing = offscreenTexture, existing.width == w, existing.height == h {
            return
        }
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: w,
            height: h,
            mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        offscreenTexture = device.makeTexture(descriptor: desc)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        ensureOffscreenTexture(drawableSize: size)
    }

    func draw(in view: MTKView) {
        guard let handler = touchHandler, handler.isActive else { return }
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let time = Float(now - startTime)
        let drawableSize = view.drawableSize
        let resolution = SIMD2<Float>(Float(drawableSize.width), Float(drawableSize.height))

        // Ensure offscreen texture exists at half resolution
        ensureOffscreenTexture(drawableSize: drawableSize)
        guard let offscreen = offscreenTexture else { return }
        let offscreenResolution = SIMD2<Float>(Float(offscreen.width), Float(offscreen.height))

        // Advance camera orbit only when not touching
        if let last = lastFrameTime, !handler.isTouching {
            cameraTime += Float(now - last)
        }
        lastFrameTime = now

        // Compute default camera distance for ~95% screen width on first frame
        if handler.cameraDistance <= 0 {
            let aspect = resolution.x / resolution.y
            let fov: Float = 1.6
            let targetHalf: Float = 0.475 * aspect
            handler.cameraDistance = sqrt((fov / targetHalf) * (fov / targetHalf) + 1.0)
        }

        // Handle discharge trigger
        if handler.dischargeTriggered {
            handler.dischargeTriggered = false
            dischargeStartTime = now
        }

        var dischargeTime: Float = -1.0
        if let start = dischargeStartTime {
            let elapsed = now - start
            if elapsed < Self.dischargeDuration {
                dischargeTime = Float(elapsed)
            } else {
                dischargeStartTime = nil
            }
        }

        // Build uniforms for starfield/composite (full drawable resolution)
        let touchSlots = handler.touchSlots
        var uniforms = Uniforms(
            time: time,
            resolution: resolution,
            cameraDistance: handler.cameraDistance,
            cameraTime: cameraTime,
            touchCount: Int32(touchSlots.count),
            dischargeTime: dischargeTime,
            gyroTilt: motionManager?.tilt ?? .zero
        )

        // Build uniforms for plasma pass (half resolution)
        var plasmaUniforms = Uniforms(
            time: time,
            resolution: offscreenResolution,
            cameraDistance: handler.cameraDistance,
            cameraTime: cameraTime,
            touchCount: Int32(touchSlots.count),
            dischargeTime: dischargeTime,
            gyroTilt: motionManager?.tilt ?? .zero
        )

        // Build touch points buffer
        var touchPoints = [TouchPoint](repeating: TouchPoint(), count: maxTouchSlots)
        for (i, slot) in touchSlots.prefix(maxTouchSlots).enumerated() {
            touchPoints[i] = TouchPoint(
                position: slot.position,
                force: slot.force,
                active: 1.0
            )
        }

        var config = plasmaConfig

        // Pass 1: Starfield -> drawable
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.005, green: 0.005, blue: 0.015, alpha: 1.0)
        descriptor.colorAttachments[0].storeAction = .store

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.setRenderPipelineState(starfieldPipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }

        // Pass 2: Plasma -> offscreen texture (half-res)
        let offscreenDescriptor = MTLRenderPassDescriptor()
        offscreenDescriptor.colorAttachments[0].texture = offscreen
        offscreenDescriptor.colorAttachments[0].loadAction = .clear
        offscreenDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        offscreenDescriptor.colorAttachments[0].storeAction = .store

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: offscreenDescriptor) {
            encoder.setRenderPipelineState(plasmaPipeline)
            encoder.setFragmentBytes(&plasmaUniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentBytes(&touchPoints, length: MemoryLayout<TouchPoint>.stride * maxTouchSlots, index: 1)
            encoder.setFragmentBytes(&config, length: MemoryLayout<PlasmaConfig>.stride, index: 2)
            encoder.setFragmentTexture(noiseTexture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }

        // Pass 3: Composite offscreen -> drawable (additive blend over starfield)
        descriptor.colorAttachments[0].loadAction = .load
        descriptor.colorAttachments[0].storeAction = .store

        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            encoder.setRenderPipelineState(compositePipeline)
            encoder.setFragmentTexture(offscreen, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
