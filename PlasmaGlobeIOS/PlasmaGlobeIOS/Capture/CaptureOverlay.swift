import SwiftUI

struct CaptureOverlay: View {
    @ObservedObject var captureManager: CaptureManager
    @ObservedObject var settings: PlasmaSettings
    @ObservedObject var breathingEngine: BreathingEngine
    var isBreathingActive: Bool

    @State private var isPanelVisible = false

    var body: some View {
        ZStack {
            // Recording indicator (always visible when recording)
            if captureManager.isRecording {
                VStack {
                    Spacer()
                    recordingIndicator
                        .padding(.bottom, isPanelVisible ? 120 : 60)
                }
            }

            // Slide-up panel
            VStack {
                Spacer()

                if isPanelVisible {
                    // Toolbar with camera, record, breathe
                    HStack(spacing: 32) {
                        cameraButton
                        if captureManager.isRecording {
                            stopButton
                        } else {
                            recordButton
                        }
                        breatheButton
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                }

                // Toggle handle
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPanelVisible.toggle()
                    }
                } label: {
                    Image(systemName: isPanelVisible ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 44, height: 28)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                }
                .padding(.bottom, 12)
            }
        }
        .opacity(isBreathingActive ? 0.15 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isBreathingActive)
        .sheet(isPresented: $captureManager.showShareSheet) {
            ShareSheet(items: captureManager.shareItems) {
                captureManager.showShareSheet = false
            }
        }
        .sheet(isPresented: $captureManager.showDurationPicker) {
            durationPicker
                .presentationDetents([.height(200)])
        }
    }

    // MARK: - Helpers

    private func dismissThenRun(_ action: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: 0.25)) {
            isPanelVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            action()
        }
    }

    // MARK: - Camera Button

    private var cameraButton: some View {
        Button {
            dismissThenRun { captureManager.takeScreenshot() }
        } label: {
            Image(systemName: "camera.fill")
                .font(.title3)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 48, height: 48)
        }
    }

    // MARK: - Record Button

    private var recordButton: some View {
        Button {
            dismissThenRun { captureManager.showDurationPicker = true }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 2.5)
                    .frame(width: 40, height: 40)
                Circle()
                    .fill(Color.red)
                    .frame(width: 28, height: 28)
            }
            .frame(width: 48, height: 48)
        }
    }

    // MARK: - Stop Button

    private var stopButton: some View {
        Button {
            dismissThenRun { captureManager.stopRecording() }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 2.5)
                    .frame(width: 40, height: 40)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red)
                    .frame(width: 18, height: 18)
            }
            .frame(width: 48, height: 48)
        }
    }

    // MARK: - Breathe Button

    private var breatheButton: some View {
        Button {
            dismissThenRun {
                let pattern = settings.breathingPattern
                let custom = pattern == .custom ? settings.customBreathingDurations : nil
                breathingEngine.start(
                    pattern: pattern,
                    customDurations: custom,
                    sessionMinutes: settings.breathingSessionMinutes
                )
            }
        } label: {
            Image(systemName: "lungs.fill")
                .font(.title3)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 48, height: 48)
        }
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(pulsingOpacity)

            Text(formattedCountdown)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.5)))
    }

    private var pulsingOpacity: Double {
        let fractional = captureManager.remainingTime.truncatingRemainder(dividingBy: 1.0)
        return fractional > 0.5 ? 1.0 : 0.4
    }

    private var formattedCountdown: String {
        let total = Int(ceil(captureManager.remainingTime))
        return "\(total)s"
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        VStack(spacing: 16) {
            Text("Recording Duration")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.top, 20)

            ForEach(RecordingDuration.allCases) { duration in
                Button {
                    settings.recordingDurationRaw = duration.rawValue
                    captureManager.startRecording(duration: duration)
                } label: {
                    Text(duration.label)
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(duration == settings.recordingDuration ? Color.purple.opacity(0.3) : Color.clear)
                        )
                        .foregroundColor(.purple)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
