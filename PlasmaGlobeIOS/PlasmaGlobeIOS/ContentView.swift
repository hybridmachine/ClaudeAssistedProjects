import SwiftUI

final class AppServices: ObservableObject {
    let audioManager = AudioManager()
    let motionManager = MotionManager()
}

struct ContentView: View {
    @StateObject private var touchHandler = TouchHandler()
    @StateObject private var settings = PlasmaSettings()
    @StateObject private var services = AppServices()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MetalView(touchHandler: touchHandler, settings: settings, motionManager: services.motionManager)
                .ignoresSafeArea()

            SettingsOverlay(settings: settings)
                .allowsHitTesting(true)
        }
        .onChange(of: scenePhase) { newPhase in
            touchHandler.isActive = (newPhase == .active)
            if newPhase == .active {
                services.audioManager.start()
                services.motionManager.start()
            } else {
                services.audioManager.stop()
                services.motionManager.stop()
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
