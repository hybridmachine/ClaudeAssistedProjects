import MetalKit
import Combine
import simd

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

        let plasmaDesc = Self.makeBasePipelineDescriptor(
            library: library, fragmentFunction: "plasmaGlobeFragment", pixelFormat: mtkView.colorPixelFormat
        )
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

    // MARK: - Constants matching Metal shader

    private static let maxTendrils = 20
    private static let maxTouches = 5
    private static let sphereR: Float = 1.0

    // MARK: - CPU tendril pre-computation helpers

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
        return t * t * (3.0 - 2.0 * t)
    }

    private static func fract(_ x: Float) -> Float {
        return x - floor(x)
    }

    private static func hashSin(_ x: Float) -> Float {
        return fract(sin(x) * 43758.5453)
    }

    private static func sphereHit(ro: SIMD3<Float>, rd: SIMD3<Float>, r: Float) -> SIMD2<Float> {
        let b = simd_dot(ro, rd)
        let c = simd_dot(ro, ro) - r * r
        let h = b * b - c
        if h < 0.0 { return SIMD2<Float>(-1.0, -1.0) }
        let sqrtH = sqrtf(h)
        return SIMD2<Float>(-b - sqrtH, -b + sqrtH)
    }

    private func computeCameraVectors(cameraTime: Float, cameraDistance: Float)
        -> (ro: SIMD3<Float>, uu: SIMD3<Float>, vv: SIMD3<Float>, ww: SIMD3<Float>)
    {
        let camAngle = cameraTime * 0.12
        let ro = SIMD3<Float>(
            sin(camAngle) * cameraDistance,
            sin(cameraTime * 0.04) * 0.15,
            cos(camAngle) * cameraDistance
        )
        let ww = simd_normalize(-ro)
        let uu = simd_normalize(simd_cross(ww, SIMD3<Float>(0, 1, 0)))
        let vv = simd_cross(uu, ww)
        return (ro, uu, vv, ww)
    }

    private func computeTouchWorldDirs(
        touches: [TouchPoint],
        touchCount: Int,
        resolution: SIMD2<Float>,
        ro: SIMD3<Float>,
        uu: SIMD3<Float>,
        vv: SIMD3<Float>,
        ww: SIMD3<Float>
    ) -> (dirs: [SIMD3<Float>], forces: [Float]) {
        var dirs = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 1), count: Self.maxTouches)
        var forces = [Float](repeating: 0.5, count: Self.maxTouches)

        for t in 0..<min(touchCount, Self.maxTouches) {
            guard touches[t].active > 0.5 else { continue }
            var tuv = touches[t].position - SIMD2<Float>(0.5, 0.5)
            tuv.x *= resolution.x / resolution.y
            let touchRd = simd_normalize(tuv.x * uu - tuv.y * vv + 1.6 * ww)
            let tHit = Self.sphereHit(ro: ro, rd: touchRd, r: Self.sphereR)
            if tHit.x > 0.0 {
                dirs[t] = simd_normalize(ro + touchRd * tHit.x)
            }
            forces[t] = touches[t].force
        }
        return (dirs, forces)
    }

    private func computeTendrilInfo(
        idx: Int,
        time: Float,
        realTime: Float,
        touchDirs: [SIMD3<Float>],
        touchForces: [Float],
        touchCount: Int,
        speed: Float,
        respawnRate: Float,
        tiltOffset: SIMD3<Float>
    ) -> TendrilInfoCPU {
        let fi = Float(idx)

        // Lifecycle
        let lifeHash = Self.fract(fi * 0.5281 + 0.321)
        let phaseHash = Self.fract(fi * 0.8713 + 0.654)
        let period = (3.0 + lifeHash * 4.0) / max(respawnRate, 0.1)
        let lifecycleTime = realTime + phaseHash * period
        let generation = floor(lifecycleTime / period)
        let timeInCycle = Self.fract(lifecycleTime / period) * period

        let genTheta = Self.hashSin(generation * 127.1 + fi * 311.7) * 6.2832
        let genPhi = Self.hashSin(generation * 269.5 + fi * 183.3)
        let genSeed = generation * 7.31

        // Organic meandering
        let wanderTheta = sin(time * 0.17 * speed + fi * 2.3 + genSeed) * 0.25
                        + sin(time * 0.11 * speed + fi * 4.1 + genSeed * 1.7) * 0.15
                        + sin(time * 0.07 * speed + fi * 6.7 + genSeed * 2.3) * 0.08
        let theta = fi * 2.39996 + genTheta + wanderTheta

        // Slow upward drift + vertical meandering
        let lifecycleProgress = timeInCycle / period
        let upwardDrift = lifecycleProgress * 0.35

        let wanderPhi = sin(time * 0.13 * speed + fi * 3.7 + genSeed * 1.3) * 0.08
                      + sin(time * 0.09 * speed + fi * 5.3 + genSeed * 2.1) * 0.05

        let cosArg = min(max(1.0 - 2.0 * genPhi + upwardDrift + wanderPhi, -1.0), 1.0)
        let phi = acos(cosArg)

        var baseDir = simd_normalize(SIMD3<Float>(
            sin(phi) * cos(theta),
            cos(phi),
            sin(phi) * sin(theta)
        ))

        var bias: Float = 0.0
        var forceScale: Float = 1.0

        if touchCount > 0 {
            var bestProximity: Float = -1.0
            var bestTouch = 0
            for t in 0..<min(touchCount, Self.maxTouches) {
                let angularDist = acos(min(max(simd_dot(baseDir, touchDirs[t]), -1.0), 1.0)) / Float.pi
                let proximity = 1.0 - angularDist
                if proximity > bestProximity {
                    bestProximity = proximity
                    bestTouch = t
                }
            }

            let localFalloff = Self.smoothstep(0.4, 0.8, bestProximity)
            let force = touchForces[bestTouch]
            bias = localFalloff * (0.7 + 0.25 * force + 0.04 * Self.fract(fi * 0.37))
            bias = min(max(bias, 0.0), 1.0)
            baseDir = simd_normalize(simd_mix(baseDir, touchDirs[bestTouch], SIMD3<Float>(repeating: bias)))
            forceScale = 1.0 + force * 0.8 * localFalloff
        }

        // Apply tilt sway
        baseDir = simd_normalize(baseDir + tiltOffset)

        let up: SIMD3<Float> = abs(baseDir.y) < 0.99 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
        let rt = simd_normalize(simd_cross(baseDir, up))
        let fw = simd_cross(rt, baseDir)

        let hash1 = Self.fract(fi * 0.7631 + 0.123 + genSeed)
        let hash2 = Self.fract(fi * 0.4519 + 0.789 + genSeed)
        let hash3 = Self.fract(fi * 0.9137 + 0.456 + genSeed)

        var info = TendrilInfoCPU()
        info.dir = baseDir
        info.right = rt
        info.fwd = fw
        info.touchBias = bias
        info.forceScale = forceScale
        info.forkPoint = 0.3 + hash1 * 0.3

        let angle1 = hash2 * Float.pi * 2.0 + time * 0.05 * speed
        info.branchOffset1 = simd_normalize(rt * cos(angle1) + fw * sin(angle1))
        let angle2 = angle1 + Float.pi * 0.6 + hash3 * 0.4
        info.branchOffset2 = simd_normalize(rt * cos(angle2) + fw * sin(angle2))
        info.branchCount = (hash3 > 0.4) ? 2 : 1

        // Lifecycle fade
        let fadeIn = Self.smoothstep(0.0, 0.2, timeInCycle)
        let fadeOut = Self.smoothstep(0.0, 0.2, period - timeInCycle)
        info.flicker = fadeIn * fadeOut

        // Per-tendril color seed
        info.colorSeed = Self.hashSin(generation * 53.7 + fi * 97.3)

        return info
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
            let targetHalf: Float = 0.35 * aspect
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

        // Build uniforms
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

        // Pre-compute tendrils on CPU (identical math to former per-pixel GPU code)
        let cam = computeCameraVectors(cameraTime: cameraTime, cameraDistance: handler.cameraDistance)
        let touchResult = computeTouchWorldDirs(
            touches: touchPoints,
            touchCount: Int(uniforms.touchCount),
            resolution: resolution,
            ro: cam.ro, uu: cam.uu, vv: cam.vv, ww: cam.ww
        )

        // Write worldDir back into touch points for shader use
        for t in 0..<min(Int(uniforms.touchCount), Self.maxTouches) {
            touchPoints[t].worldDir = touchResult.dirs[t]
        }

        let tilt = motionManager?.tilt ?? .zero
        let tiltOffset = SIMD3<Float>(tilt.x, 0.0, tilt.y) * 0.15
        let animTime = time * config.speed
        let numTendrils = min(max(Int(config.tendrilCount), 1), Self.maxTendrils)

        var tendrilInfos = [TendrilInfoCPU](repeating: TendrilInfoCPU(), count: Self.maxTendrils)
        for j in 0..<numTendrils {
            tendrilInfos[j] = computeTendrilInfo(
                idx: j,
                time: animTime,
                realTime: time,
                touchDirs: touchResult.dirs,
                touchForces: touchResult.forces,
                touchCount: Int(uniforms.touchCount),
                speed: config.speed,
                respawnRate: config.respawnRate,
                tiltOffset: tiltOffset
            )
        }

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
            encoder.setFragmentBytes(&touchPoints, length: MemoryLayout<TouchPoint>.stride * maxTouchSlots, index: 1)
            encoder.setFragmentBytes(&config, length: MemoryLayout<PlasmaConfig>.stride, index: 2)
            encoder.setFragmentBytes(&tendrilInfos, length: MemoryLayout<TendrilInfoCPU>.stride * Self.maxTendrils, index: 3)
            encoder.setFragmentTexture(noiseTexture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
