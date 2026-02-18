import SwiftUI

struct ThemePickerSection: View {
    @ObservedObject var settings: PlasmaSettings
    var onInteraction: () -> Void

    var body: some View {
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
        Color(red: 1.0, green: 0.2, blue: 0.15) // wrap back to red
    ]

    private func themeButton(_ theme: ColorTheme) -> some View {
        let colors = theme.previewColors
        let isSelected = settings.selectedThemeId == theme.id

        return Button {
            settings.selectedThemeId = theme.id
            onInteraction()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if theme.isRainbow {
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: Self.rainbowPreviewColors,
                                    center: .center
                                )
                            )
                            .frame(width: 36, height: 36)
                    } else {
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
                    }

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
}
