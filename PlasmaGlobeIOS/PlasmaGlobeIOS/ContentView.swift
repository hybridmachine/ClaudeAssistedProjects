import SwiftUI

final class AppServices: ObservableObject {
    let audioManager = AudioManager()
    let motionManager = MotionManager()
    let hapticManager = HapticManager()
}

struct ContentView: View {
    @StateObject private var touchHandler = TouchHandler()
    @StateObject private var settings = PlasmaSettings()
    @StateObject private var services = AppServices()
    @StateObject private var breathingEngine = BreathingEngine()
    @StateObject private var captureManager = CaptureManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MetalView(touchHandler: touchHandler, settings: settings, motionManager: services.motionManager, breathingEngine: breathingEngine, captureManager: captureManager)
                .ignoresSafeArea()

            BreathingOverlay(engine: breathingEngine, settings: settings)

            CaptureOverlay(captureManager: captureManager, settings: settings, breathingEngine: breathingEngine, isBreathingActive: breathingEngine.isActive)

            SettingsOverlay(settings: settings, isBreathingActive: breathingEngine.isActive)
                .allowsHitTesting(true)
                .opacity(breathingEngine.isActive ? 0.15 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: breathingEngine.isActive)
        }
        .onChange(of: scenePhase) { newPhase in
            touchHandler.isActive = (newPhase == .active)
            if newPhase == .active {
                services.audioManager.start()
                services.motionManager.start()
            } else {
                services.audioManager.stop()
                services.motionManager.stop()
                // Stop breathing session on background
                if breathingEngine.isActive {
                    breathingEngine.stop()
                }
                // Stop recording on background
                if captureManager.isRecording {
                    captureManager.stopRecording()
                }
            }
        }
        .onChange(of: settings.tiltEnabled) { enabled in
            services.motionManager.isEnabled = enabled
        }
        .onChange(of: settings.soundEnabled) { enabled in
            services.audioManager.setEnabled(enabled)
        }
        .onChange(of: settings.soundVolume) { vol in
            services.audioManager.updateVolume(Float(vol))
        }
        .onChange(of: settings.dischargeSoundStyleId) { _ in
            services.audioManager.setDischargeSoundStyle(settings.dischargeSoundStyle)
        }
        .onChange(of: settings.humFrequency) { freq in
            services.audioManager.setHumFrequency(Float(freq))
        }
        // Breathing state transitions: haptic cues + chime
        .onChange(of: breathingEngine.currentState.rawValue) { _ in
            let state = breathingEngine.currentState
            let previous = breathingEngine.previousState

            if settings.hapticsEnabled {
                switch state {
                case .inhale:
                    services.hapticManager.playBreathingCue(isInhale: true)
                case .exhale:
                    services.hapticManager.playBreathingCue(isInhale: false)
                case .idle:
                    // Session ended
                    if previous != .idle {
                        services.hapticManager.playSessionComplete()
                    }
                default:
                    break
                }
            }

            // Chime on breath transitions
            if settings.breathingChimeEnabled && settings.soundEnabled {
                if state == .inhale || state == .exhale {
                    services.audioManager.triggerBreathingChime()
                }
            }
        }
        // Breathing audio modulation
        .onChange(of: breathingEngine.breathPhase) { _ in
            services.audioManager.setBreathingParams(
                active: breathingEngine.isActive,
                intensity: breathingEngine.breathingIntensity
            )
        }
        // Also update when breathing stops
        .onChange(of: breathingEngine.isActive) { active in
            if !active {
                services.audioManager.setBreathingParams(active: false, intensity: 0)
            }
        }
        .onAppear {
            touchHandler.audioManager = services.audioManager
            services.motionManager.isEnabled = settings.tiltEnabled
            services.audioManager.setEnabled(settings.soundEnabled)
            services.audioManager.updateVolume(Float(settings.soundVolume))
            services.audioManager.setDischargeSoundStyle(settings.dischargeSoundStyle)
            services.audioManager.setHumFrequency(Float(settings.humFrequency))
            services.audioManager.start()
            services.motionManager.start()
        }
    }
}
