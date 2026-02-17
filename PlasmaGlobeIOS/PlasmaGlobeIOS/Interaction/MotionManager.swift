import CoreMotion
import simd

final class MotionManager {
    private let motionManager = CMMotionManager()
    private var rawTilt: SIMD2<Float> = .zero
    var isEnabled: Bool = true

    var tilt: SIMD2<Float> {
        isEnabled ? rawTilt : .zero
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            // Map pitch/roll to [-1, 1] over +/-45 degrees
            let maxAngle: Double = .pi / 4.0
            let pitch = Float(max(-1, min(1, motion.attitude.pitch / maxAngle)))
            let roll = Float(max(-1, min(1, motion.attitude.roll / maxAngle)))
            self.rawTilt = SIMD2<Float>(roll, pitch)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        rawTilt = .zero
    }
}
