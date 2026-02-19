import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    @ObservedObject var touchHandler: TouchHandler
    @ObservedObject var settings: PlasmaSettings
    var motionManager: MotionManager?

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.preferredFramesPerSecond = 60
        mtkView.clearColor = MTLClearColor(red: 0.005, green: 0.005, blue: 0.015, alpha: 1.0)
        mtkView.delegate = context.coordinator
        mtkView.isMultipleTouchEnabled = true

        let multiTouch = MultiTouchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMultiTouch(_:))
        )

        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )

        multiTouch.setPinchRecognizer(pinchGesture)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2

        mtkView.addGestureRecognizer(multiTouch)
        mtkView.addGestureRecognizer(pinchGesture)
        mtkView.addGestureRecognizer(doubleTap)

        pinchGesture.delegate = context.coordinator
        multiTouch.delegate = context.coordinator

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.isPaused = !touchHandler.isActive
        uiView.preferredFramesPerSecond = settings.preferredFPS
        context.coordinator.updateSettings(settings)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(touchHandler: touchHandler, settings: settings, motionManager: motionManager)
    }

    final class Coordinator: NSObject, MTKViewDelegate, UIGestureRecognizerDelegate {
        private var renderer: PlasmaRenderer?
        private let touchHandler: TouchHandler
        private var settings: PlasmaSettings
        private var motionManager: MotionManager?

        init(touchHandler: TouchHandler, settings: PlasmaSettings, motionManager: MotionManager?) {
            self.touchHandler = touchHandler
            self.settings = settings
            self.motionManager = motionManager
            super.init()
        }

        func updateSettings(_ settings: PlasmaSettings) {
            self.settings = settings
            renderer?.plasmaConfig = settings.buildPlasmaConfig()
            touchHandler.hapticsEnabled = settings.hapticsEnabled
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            ensureRendererInitialized(for: view)
            renderer?.mtkView(view, drawableSizeWillChange: size)
        }

        func draw(in view: MTKView) {
            ensureRendererInitialized(for: view)
            renderer?.draw(in: view)
        }

        private func ensureRendererInitialized(for view: MTKView) {
            guard renderer == nil else { return }
            renderer = PlasmaRenderer(mtkView: view, touchHandler: touchHandler)
            renderer?.plasmaConfig = settings.buildPlasmaConfig()
            renderer?.motionManager = motionManager
        }

        @objc func handleMultiTouch(_ gesture: MultiTouchGestureRecognizer) {
            guard let view = gesture.view else { return }
            switch gesture.state {
            case .began, .changed:
                let slots = gesture.activeTouchData(in: view)
                let adjustedSlots = slots.compactMap { slot in
                    adjustTouchForGlobe(slot, viewSize: view.bounds.size)
                }
                touchHandler.updateTouches(adjustedSlots)
            case .ended, .cancelled, .failed:
                touchHandler.endAllTouches()
            default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                touchHandler.beginPinch()
            case .changed:
                touchHandler.updatePinch(scale: gesture.scale)
            default:
                break
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            let normalizedX = Float(location.x / view.bounds.width)
            let normalizedY = Float(location.y / view.bounds.height)
            guard isTouchInGlobeZone(normalizedX: normalizedX,
                                    normalizedY: normalizedY,
                                    viewSize: view.bounds.size) else { return }
            touchHandler.triggerDischarge()
        }

        // MARK: - Globe Hit Testing

        private func globeScreenRadius() -> Float {
            let dist = touchHandler.cameraDistance
            guard dist > 1.0 else { return 1000.0 }
            return 1.6 * tan(asin(1.0 / dist))
        }

        private func globeOffsetAndDistance(normalizedX: Float, normalizedY: Float, viewSize: CGSize) -> (dx: Float, dy: Float, distance: Float) {
            let aspect = Float(viewSize.width / viewSize.height)
            let dx = (normalizedX - 0.5) * aspect
            let dy = normalizedY - 0.5
            return (dx, dy, sqrt(dx * dx + dy * dy))
        }

        private func isTouchInGlobeZone(normalizedX: Float, normalizedY: Float, viewSize: CGSize) -> Bool {
            let (_, _, distance) = globeOffsetAndDistance(normalizedX: normalizedX, normalizedY: normalizedY, viewSize: viewSize)
            return distance <= globeScreenRadius() * 1.15
        }

        private func adjustTouchForGlobe(_ slot: TouchSlot, viewSize: CGSize) -> TouchSlot? {
            let (dx, dy, distance) = globeOffsetAndDistance(normalizedX: slot.position.x, normalizedY: slot.position.y, viewSize: viewSize)
            let aspect = Float(viewSize.width / viewSize.height)
            let radius = globeScreenRadius()
            let marginRadius = radius * 1.15

            if distance <= radius {
                // On globe: pass through unchanged
                return slot
            } else if distance <= marginRadius {
                // Margin zone: project slightly inside globe edge so the shader's
                // ray-sphere intersection succeeds (exact edge gives a tangent ray
                // that misses due to floating-point precision)
                let marginDepth = (distance - radius) / (radius * 0.15)
                let forceScale: Float = 1.0 - marginDepth * 0.8
                let safeRadius = radius * 0.95
                let projectedX = (dx / distance * safeRadius) / aspect + 0.5
                let projectedY = (dy / distance * safeRadius) + 0.5
                return TouchSlot(
                    position: SIMD2<Float>(projectedX, projectedY),
                    force: slot.force * forceScale
                )
            } else {
                // Outside margin: reject
                return nil
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}
