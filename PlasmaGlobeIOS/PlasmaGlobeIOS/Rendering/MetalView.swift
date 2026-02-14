import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    @ObservedObject var touchHandler: TouchHandler

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.preferredFramesPerSecond = 60
        mtkView.clearColor = MTLClearColor(red: 0.005, green: 0.005, blue: 0.015, alpha: 1.0)
        mtkView.delegate = context.coordinator
        mtkView.isMultipleTouchEnabled = true

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        mtkView.addGestureRecognizer(panGesture)

        let tapGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        tapGesture.minimumPressDuration = 0
        mtkView.addGestureRecognizer(tapGesture)

        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        mtkView.addGestureRecognizer(pinchGesture)

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        uiView.isPaused = !touchHandler.isActive
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(touchHandler: touchHandler)
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        private var renderer: PlasmaRenderer?
        private let touchHandler: TouchHandler

        init(touchHandler: TouchHandler) {
            self.touchHandler = touchHandler
            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if renderer == nil {
                renderer = PlasmaRenderer(mtkView: view, touchHandler: touchHandler)
            }
            renderer?.mtkView(view, drawableSizeWillChange: size)
        }

        func draw(in view: MTKView) {
            if renderer == nil {
                renderer = PlasmaRenderer(mtkView: view, touchHandler: touchHandler)
            }
            renderer?.draw(in: view)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            switch gesture.state {
            case .began, .changed:
                touchHandler.updateTouch(location: location, viewSize: view.bounds.size)
            case .ended, .cancelled, .failed:
                touchHandler.endTouch()
            default:
                break
            }
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            switch gesture.state {
            case .began, .changed:
                touchHandler.updateTouch(location: location, viewSize: view.bounds.size)
            case .ended, .cancelled, .failed:
                touchHandler.endTouch()
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
    }
}
