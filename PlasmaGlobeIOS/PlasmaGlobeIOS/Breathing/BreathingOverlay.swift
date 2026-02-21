import SwiftUI

struct BreathingOverlay: View {
    @ObservedObject var engine: BreathingEngine
    @ObservedObject var settings: PlasmaSettings

    var body: some View {
        ZStack {
            if engine.isActive {
                activeOverlay
            } else {
                startButton
            }
        }
    }

    // MARK: - Active Session

    private var activeOverlay: some View {
        ZStack {
            // Tap anywhere to stop
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    engine.stop()
                }

            // Session timer (top-left)
            if settings.breathingSessionMinutes > 0 {
                VStack {
                    HStack {
                        Text(formattedTime)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.leading, 20)
                            .padding(.top, 60)
                        Spacer()
                    }
                    Spacer()
                }
            }

            // Breath label below globe
            VStack {
                Spacer()

                Text(breathLabel)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .animation(.easeInOut(duration: 0.4), value: engine.currentState.rawValue)
                    .padding(.bottom, 80)
            }
        }
        .allowsHitTesting(true)
    }

    // MARK: - Start Button

    private var startButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    let pattern = settings.breathingPattern
                    let custom = pattern == .custom ? settings.customBreathingDurations : nil
                    engine.start(
                        pattern: pattern,
                        customDurations: custom,
                        sessionMinutes: settings.breathingSessionMinutes
                    )
                } label: {
                    Image(systemName: "lungs.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.trailing, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Helpers

    private var breathLabel: String {
        switch engine.currentState {
        case .idle: return ""
        case .inhale: return "Breathe In"
        case .hold: return "Hold"
        case .exhale: return "Breathe Out"
        case .holdAfterExhale: return "Hold"
        }
    }

    private var formattedTime: String {
        let total = Int(engine.remainingTime)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
