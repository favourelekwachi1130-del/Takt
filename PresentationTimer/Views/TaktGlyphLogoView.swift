import SwiftUI

/// Three-bar mark matching the app icon: accent (top) + charcoal pills — updates with **TaktTheme.accent**.
struct TaktGlyphLogoView: View {
    var accent: Color

    private var darkFill: Color {
        Color(red: 0.13, green: 0.13, blue: 0.13)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            pill(width: 18, height: 5, fill: accent)
            pill(width: 29, height: 5, fill: darkFill)
            pill(width: 22, height: 5, fill: darkFill)
        }
        .accessibilityHidden(true)
    }

    private func pill(width: CGFloat, height: CGFloat, fill: Color) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        fill.opacity(0.92),
                        fill
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .frame(width: width, height: height)
    }
}

#Preview {
    TaktGlyphLogoView(accent: .orange)
        .padding()
}
