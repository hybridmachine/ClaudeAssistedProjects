import UIKit
import UIKit.UIGestureRecognizerSubclass

final class MultiTouchGestureRecognizer: UIGestureRecognizer {
    private(set) var trackedTouches: [UITouch] = []
    private var pinchRecognizer: UIPinchGestureRecognizer?

    var maxTouches: Int = 5

    func setPinchRecognizer(_ pinch: UIPinchGestureRecognizer) {
        self.pinchRecognizer = pinch
    }

    private func isClaimedByPinch(_ touch: UITouch) -> Bool {
        guard let pinch = pinchRecognizer else { return false }
        let pinchState = pinch.state
        guard pinchState == .began || pinchState == .changed else { return false }
        return pinch.numberOfTouches >= 2
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            guard trackedTouches.count < maxTouches else { break }
            if !trackedTouches.contains(touch) {
                trackedTouches.append(touch)
            }
        }
        if state == .possible {
            state = .began
        } else {
            state = .changed
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        removeTouches(touches, terminalState: .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        removeTouches(touches, terminalState: .cancelled)
    }

    private func removeTouches(_ touches: Set<UITouch>, terminalState: UIGestureRecognizer.State) {
        trackedTouches.removeAll { touches.contains($0) }
        state = trackedTouches.isEmpty ? terminalState : .changed
    }

    override func reset() {
        trackedTouches.removeAll()
        super.reset()
    }

    func activeTouchData(in view: UIView) -> [TouchSlot] {
        var slots: [TouchSlot] = []
        for touch in trackedTouches {
            if isClaimedByPinch(touch) { continue }
            let location = touch.location(in: view)
            let x = Float(location.x / view.bounds.width)
            let y = Float(location.y / view.bounds.height)
            let force: Float
            if touch.maximumPossibleForce > 0 {
                force = Float(touch.force / touch.maximumPossibleForce)
            } else {
                force = 0.5
            }
            slots.append(TouchSlot(position: SIMD2<Float>(x, y), force: force))
            if slots.count >= maxTouches { break }
        }
        return slots
    }
}

struct TouchSlot {
    var position: SIMD2<Float>
    var force: Float
}
