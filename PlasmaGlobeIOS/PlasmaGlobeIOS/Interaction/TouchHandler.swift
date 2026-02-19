import UIKit
import Combine

final class TouchHandler: ObservableObject {
    var touchSlots: [TouchSlot] = []
    @Published var isActive: Bool = true
    @Published var cameraDistance: Float = 0.0
    @Published var dischargeTriggered: Bool = false

    static let minDistance: Float = 1.5
    static let maxDistance: Float = 20.0

    private var pinchStartDistance: Float = 0.0

    let hapticManager = HapticManager()
    var audioManager: AudioManager?
    var hapticsEnabled: Bool = true

    var isTouching: Bool { !touchSlots.isEmpty }

    var maxForce: Float {
        touchSlots.map(\.force).max() ?? 0.0
    }

    func beginPinch() {
        pinchStartDistance = cameraDistance
    }

    func updatePinch(scale: CGFloat) {
        let newDistance = pinchStartDistance / Float(scale)
        cameraDistance = min(max(newDistance, Self.minDistance), Self.maxDistance)
    }

    func updateTouches(_ slots: [TouchSlot]) {
        let wasTouching = isTouching
        touchSlots = slots

        if hapticsEnabled {
            if !wasTouching && isTouching {
                hapticManager.startContinuous()
            }
            if isTouching {
                hapticManager.updateForce(maxForce)
            }
        }

        if isTouching {
            audioManager?.setCrackle(force: maxForce)
        } else if wasTouching {
            audioManager?.stopCrackle()
        }
    }

    func endAllTouches() {
        touchSlots = []
        hapticManager.stop()
        audioManager?.stopCrackle()
    }

    func triggerDischarge() {
        dischargeTriggered = true
        if hapticsEnabled {
            hapticManager.playDischargeBurst()
        }
        audioManager?.triggerDischarge()
    }
}
