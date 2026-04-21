import SwiftUI

/// Visual language: high-contrast fitness-style surfaces, dark default, optional light mode.
enum TaktTheme {
    /// Primary accent — asset-backed for light/dark variants.
    static let accent = Color("TaktAccent")

    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.07, blue: 0.09)
            : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.12, blue: 0.16)
            : Color.white
    }

    static func cardBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }

    static func secondaryLabel(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.55)
            : Color.black.opacity(0.45)
    }

    static let ringGradient = LinearGradient(
        colors: [
            Color(red: 0.25, green: 0.88, blue: 0.78),
            Color(red: 0.20, green: 0.55, blue: 0.95)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.12, green: 0.45, blue: 0.52).opacity(0.55),
            Color(red: 0.08, green: 0.10, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Live timer ring: steady segment, pacing zone (after first cue), final segment “home stretch.”
    enum SessionRingPhase: Sendable {
        case steady
        case pacing
        case finalStretch
    }

    static func sessionRingGradient(for phase: SessionRingPhase) -> LinearGradient {
        switch phase {
        case .steady:
            return LinearGradient(
                colors: [
                    Color(red: 0.25, green: 0.88, blue: 0.78),
                    Color(red: 0.20, green: 0.55, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pacing:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.78, blue: 0.35),
                    Color(red: 0.95, green: 0.45, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .finalStretch:
            return LinearGradient(
                colors: [
                    Color(red: 0.65, green: 0.45, blue: 1.0),
                    Color(red: 0.95, green: 0.35, blue: 0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

extension TaktTheme {
    /// Derives ring emphasis from segment position and pacing-cue threshold (same rules as live timer).
    static func sessionRingPhase(engine: TimerEngine, preset: Preset) -> SessionRingPhase {
        let segments = engine.segments
        guard !segments.isEmpty else { return .steady }
        let count = segments.count
        let idx = engine.currentSegmentIndex
        if idx >= count - 1 { return .finalStretch }
        let dur = engine.currentSegmentDuration
        guard dur > 0 else { return .steady }
        if engine.elapsedInCurrentSegment >= engine.firstCueFraction * dur {
            return .pacing
        }
        return .steady
    }
}

struct TaktCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(TaktTheme.cardBackground(for: colorScheme))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.08), radius: 16, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(TaktTheme.cardBorder(for: colorScheme), lineWidth: 1)
            )
    }
}

extension View {
    func taktCardStyle() -> some View {
        modifier(TaktCardModifier())
    }

    func taktScreenBackground() -> some View {
        modifier(TaktScreenBackgroundModifier())
    }
}

private struct TaktScreenBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                TaktTheme.background(for: colorScheme)
                    .ignoresSafeArea()
            )
    }
}

