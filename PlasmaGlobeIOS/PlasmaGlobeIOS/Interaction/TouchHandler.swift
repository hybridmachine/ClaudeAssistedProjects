import UIKit
import Combine

final class TouchHandler: ObservableObject {
    @Published var touchPosition: SIMD2<Float> = .init(0.5, 0.5)
    @Published var isTouching: Bool = false
    @Published var isActive: Bool = true
    @Published var cameraDistance: Float = 0.0 // 0 = compute default on first frame

    static let minDistance: Float = 1.5
    static let maxDistance: Float = 20.0

    private var pinchStartDistance: Float = 0.0

    func beginPinch() {
        pinchStartDistance = cameraDistance
    }

    func updatePinch(scale: CGFloat) {
        let newDistance = pinchStartDistance / Float(scale)
        cameraDistance = min(max(newDistance, Self.minDistance), Self.maxDistance)
    }

    func updateTouch(location: CGPoint, viewSize: CGSize) {
        let x = Float(location.x / viewSize.width)
        let y = Float(location.y / viewSize.height)
        touchPosition = SIMD2<Float>(x, y)
        isTouching = true
    }

    func endTouch() {
        isTouching = false
    }
}
