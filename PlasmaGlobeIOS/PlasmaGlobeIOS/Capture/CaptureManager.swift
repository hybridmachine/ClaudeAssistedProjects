import UIKit
import SwiftUI
import ReplayKit

enum RecordingDuration: Int, CaseIterable, Identifiable {
    case fiveSeconds = 5
    case tenSeconds = 10
    case fifteenSeconds = 15

    var id: Int { rawValue }

    var label: String {
        "\(rawValue)s"
    }
}

final class CaptureManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var remainingTime: Double = 0
    @Published var showShareSheet = false
    @Published var shareItems: [Any] = []
    @Published var errorMessage: String?
    @Published var showDurationPicker = false

    /// Wired by MetalView to request a screenshot from the renderer
    var requestScreenshotAsync: ((@escaping (UIImage?) -> Void) -> Void)?

    private var countdownTimer: Timer?
    private var recordingDuration: RecordingDuration = .tenSeconds

    // MARK: - Screenshot

    func takeScreenshot() {
        guard let request = requestScreenshotAsync else {
            errorMessage = "Screenshot not available"
            return
        }
        request { [weak self] image in
            guard let self, let image else {
                self?.errorMessage = "Failed to capture screenshot"
                return
            }
            self.shareItems = [image, "Created with Phase Zen" as Any]
            self.showShareSheet = true
        }
    }

    // MARK: - Video Recording

    func startRecording(duration: RecordingDuration) {
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else {
            errorMessage = "Screen recording is not available"
            return
        }

        showDurationPicker = false
        recordingDuration = duration
        remainingTime = Double(duration.rawValue)

        recorder.startRecording { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.errorMessage = "Recording failed: \(error.localizedDescription)"
                    return
                }
                self?.isRecording = true
                self?.startCountdown()
            }
        }
    }

    func stopRecording() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        let recorder = RPScreenRecorder.shared()
        guard recorder.isRecording else {
            isRecording = false
            return
        }

        recorder.stopRecording { [weak self] previewController, error in
            DispatchQueue.main.async {
                self?.isRecording = false
                self?.remainingTime = 0

                if let error {
                    self?.errorMessage = "Stop recording failed: \(error.localizedDescription)"
                    return
                }

                guard let previewController else {
                    self?.errorMessage = "No preview available"
                    return
                }

                previewController.previewControllerDelegate = self
                Self.presentViewController(previewController)
            }
        }
    }

    // MARK: - Private

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remainingTime -= 0.1
            if self.remainingTime <= 0 {
                self.remainingTime = 0
                self.stopRecording()
            }
        }
    }

    private static func presentViewController(_ vc: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        vc.modalPresentationStyle = .fullScreen
        topVC.present(vc, animated: true)
    }
}

// MARK: - RPPreviewViewControllerDelegate

extension CaptureManager: RPPreviewViewControllerDelegate {
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true)
    }
}
