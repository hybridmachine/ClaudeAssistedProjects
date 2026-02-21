import SwiftUI

struct BreathingSettingsSection: View {
    @ObservedObject var settings: PlasmaSettings
    var onInteraction: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Pattern")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Picker("", selection: $settings.breathingPatternId) {
                    ForEach(BreathingPattern.allCases) { pattern in
                        Text(pattern.name).tag(pattern.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(.purple)
                .onChange(of: settings.breathingPatternId) { _ in onInteraction() }
            }

            HStack {
                Text("Session")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Picker("", selection: $settings.breathingSessionMinutes) {
                    ForEach(SessionDuration.allCases) { duration in
                        Text(duration.name).tag(duration.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(.purple)
                .onChange(of: settings.breathingSessionMinutes) { _ in onInteraction() }
            }

            if settings.breathingPattern == .custom {
                durationSlider(label: "Inhale", value: $settings.customInhaleDuration)
                durationSlider(label: "Hold", value: $settings.customHoldDuration)
                durationSlider(label: "Exhale", value: $settings.customExhaleDuration)
                durationSlider(label: "Hold After", value: $settings.customHoldAfterExhaleDuration)
            }

            Toggle("Transition Chime", isOn: $settings.breathingChimeEnabled)
                .plasmaToggleStyle()
                .onChange(of: settings.breathingChimeEnabled) { _ in onInteraction() }
        }
    }

    private func durationSlider(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(String(format: "%.1fs", value.wrappedValue))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Slider(value: value, in: 0...15, step: 0.5)
                .tint(.purple)
                .onChange(of: value.wrappedValue) { _ in onInteraction() }
        }
    }
}
