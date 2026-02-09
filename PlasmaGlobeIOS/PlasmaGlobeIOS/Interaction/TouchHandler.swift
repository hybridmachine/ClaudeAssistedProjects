import UIKit
import Combine

final class TouchHandler: ObservableObject {
    @Published var touchPosition: SIMD2<Float> = .init(0.5, 0.5)
    @Published var isTouching: Bool = false
    @Published var isActive: Bool = true

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
