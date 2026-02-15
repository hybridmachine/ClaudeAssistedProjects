import SwiftUI

struct SettingsOverlay: View {
    @ObservedObject var settings: PlasmaSettings
    @State private var isVisible = false
    @State private var hideTimer: Timer?

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible.toggle()
                    }
                    resetHideTimer()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }

            if isVisible {
                settingsPanel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Spacer()
        }
        .onDisappear {
            hideTimer?.invalidate()
            hideTimer = nil
        }
    }

    private var settingsPanel: some View {
        VStack(spacing: 16) {
            // Theme picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ColorTheme.allThemes) { theme in
                            themeButton(theme)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            Divider().background(Color.white.opacity(0.2))

            // Sliders
            settingsSlider(label: "Tendrils", value: $settings.tendrilCount, range: 4...20, step: 1) {
                Text("\(Int(settings.tendrilCount))")
            }

            settingsSlider(label: "Brightness", value: $settings.brightness, range: 0.2...2.0)

            settingsSlider(label: "Speed", value: $settings.speed, range: 0.2...3.0)

            settingsSlider(label: "Thickness", value: $settings.tendrilThickness, range: 0.5...2.0)

            Divider().background(Color.white.opacity(0.2))

            // Toggles
            Toggle("Haptics", isOn: $settings.hapticsEnabled)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .tint(.purple)

            Toggle("Sound", isOn: $settings.soundEnabled)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .tint(.purple)

            if settings.soundEnabled {
                settingsSlider(label: "Volume", value: $settings.soundVolume, range: 0...1)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func themeButton(_ theme: ColorTheme) -> some View {
        let colors = theme.previewColors
        let isSelected = settings.selectedThemeId == theme.id

        return Button {
            settings.selectedThemeId = theme.id
            resetHideTimer()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: Double(colors.0.x), green: Double(colors.0.y), blue: Double(colors.0.z)),
                                    Color(red: Double(colors.1.x), green: Double(colors.1.y), blue: Double(colors.1.z))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    if isSelected {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                }

                Text(theme.name)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 52)
        }
    }

    private func settingsSlider<V: View>(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double? = nil,
        @ViewBuilder valueLabel: () -> V = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                valueLabel()
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            if let step = step {
                Slider(value: value, in: range, step: step) {
                    EmptyView()
                }
                .tint(.purple)
                .onChange(of: value.wrappedValue) { _ in resetHideTimer() }
            } else {
                Slider(value: value, in: range) {
                    EmptyView()
                }
                .tint(.purple)
                .onChange(of: value.wrappedValue) { _ in resetHideTimer() }
            }
        }
    }

    private func resetHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = false
            }
        }
    }
}
