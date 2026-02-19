import SwiftUI

struct ThemePickerSection: View {
    @ObservedObject var settings: PlasmaSettings
    var onInteraction: () -> Void

    private var currentMode: ThemeMode {
        ThemeMode(rawValue: settings.themeMode) ?? .custom
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 12) {
                modeButton(.custom, label: "Custom") {
                    customPreviewCircle
                }
                modeButton(.void, label: "Void") {
                    voidPreviewCircle
                }
                modeButton(.rainbow, label: "Rainbow") {
                    rainbowPreviewCircle
                }
            }

            if currentMode == .custom {
                VStack(spacing: 10) {
                    ColorPicker("Tendril Color", selection: tendrilColorBinding, supportsOpacity: false)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                    ColorPicker("Endpoint Color", selection: endpointColorBinding, supportsOpacity: false)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentMode)
    }

    // MARK: - Mode Button

    private func modeButton<Preview: View>(_ mode: ThemeMode, label: String, @ViewBuilder preview: () -> Preview) -> some View {
        let isSelected = currentMode == mode
        return Button {
            settings.themeMode = mode.rawValue
            onInteraction()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    preview()
                        .frame(width: 36, height: 36)

                    if isSelected {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .frame(width: 40, height: 40)
                    }
                }

                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 52)
        }
    }

    // MARK: - Preview Circles

    private var customPreviewCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [settings.customTendrilColor, settings.customEndpointColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var voidPreviewCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.6, green: 0.6, blue: 0.7),
                        Color(red: 0.08, green: 0.08, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private static let rainbowPreviewColors: [Color] = [
        Color(red: 1.0, green: 0.2, blue: 0.15),
        Color(red: 1.0, green: 0.55, blue: 0.1),
        Color(red: 1.0, green: 0.85, blue: 0.1),
        Color(red: 0.2, green: 0.9, blue: 0.3),
        Color(red: 0.1, green: 0.8, blue: 0.8),
        Color(red: 0.2, green: 0.4, blue: 1.0),
        Color(red: 0.45, green: 0.2, blue: 0.95),
        Color(red: 0.9, green: 0.2, blue: 0.7),
        Color(red: 1.0, green: 0.2, blue: 0.15)
    ]

    private var rainbowPreviewCircle: some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: Self.rainbowPreviewColors,
                    center: .center
                )
            )
    }

    // MARK: - Color Bindings

    private var tendrilColorBinding: Binding<Color> {
        Binding(
            get: { settings.customTendrilColor },
            set: { newColor in
                settings.customTendrilColor = newColor
                onInteraction()
            }
        )
    }

    private var endpointColorBinding: Binding<Color> {
        Binding(
            get: { settings.customEndpointColor },
            set: { newColor in
                settings.customEndpointColor = newColor
                onInteraction()
            }
        )
    }
}
