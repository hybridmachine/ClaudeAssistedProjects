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
            if renderer == nil {
                renderer = PlasmaRenderer(mtkView: view, touchHandler: touchHandler)
                renderer?.plasmaConfig = settings.buildPlasmaConfig()
                renderer?.motionManager = motionManager
            }
            renderer?.mtkView(view, drawableSizeWillChange: size)
        }

        func draw(in view: MTKView) {
            if renderer == nil {
                renderer = PlasmaRenderer(mtkView: view, touchHandler: touchHandler)
                renderer?.plasmaConfig = settings.buildPlasmaConfig()
                renderer?.motionManager = motionManager
            }
            renderer?.draw(in: view)
        }

        @objc func handleMultiTouch(_ gesture: MultiTouchGestureRecognizer) {
            guard let view = gesture.view else { return }
            switch gesture.state {
            case .began, .changed:
                let slots = gesture.activeTouchData(in: view)
                touchHandler.updateTouches(slots)
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
            touchHandler.triggerDischarge()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}
