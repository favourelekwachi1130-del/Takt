import SwiftUI

/// Visual language: user-chosen accent on neutral surfaces; cards use **material** (iOS glass) + rim + shadow.
enum TaktTheme {
    static var accent: Color { TaktAccentPalette.resolved().primary }

    /// Secondary accent for icons and emphasis where `accent` is already used nearby.
    static var accentSecondary: Color { TaktAccentPalette.resolved().secondary }

    /// Solid fills for primary buttons, icons, and recap affordances.
    static var primaryFill: Color { accent }

    /// Flat hero-style panel for **exported** recap images (no material).
    static var heroShareCardFill: Color { TaktAccentPalette.resolved().heroShareCardFill }

    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.07, green: 0.06, blue: 0.06)
            : Color(red: 0.97, green: 0.96, blue: 0.95)
    }

    /// Root backdrop: neutral base plus a soft accent wash (updates with accent palette).
    @ViewBuilder
    static func rootBackdrop(for colorScheme: ColorScheme) -> some View {
        ZStack {
            background(for: colorScheme)
            LinearGradient(
                colors: [
                    accent.opacity(colorScheme == .dark ? 0.11 : 0.055),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.42)
            )
        }
    }

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.11, blue: 0.10)
            : Color.white
    }

    static func cardBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)
    }

    static func secondaryLabel(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.55)
            : Color.black.opacity(0.45)
    }

    static func iconNeutral(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.48) : Color.black.opacity(0.38)
    }

    /// Live timer ring: steady, pacing zone, final segment — distinct solids per palette.
    enum SessionRingPhase: Sendable {
        case steady
        case pacing
        case finalStretch
    }

    static func sessionRingColor(for phase: SessionRingPhase) -> Color {
        let p = TaktAccentPalette.resolved()
        switch phase {
        case .steady:
            return p.primary
        case .pacing:
            return p.ringPacing
        case .finalStretch:
            return p.ringDeep
        }
    }
}

extension TaktTheme {
    static func sessionRingPhase(engine: TimerEngine, preset: Preset) -> SessionRingPhase {
        let segments = engine.segments
        guard !segments.isEmpty else { return .steady }
        let count = segments.count
        let idx = engine.currentSegmentIndex
        if idx >= count - 1 { return .finalStretch }
        let dur = engine.currentSegmentDuration
        guard dur > 0 else { return .steady }
        let elapsed = engine.elapsedInCurrentSegment
        if elapsed >= engine.secondCueFraction * dur {
            return .finalStretch
        }
        if elapsed >= engine.firstCueFraction * dur {
            return .pacing
        }
        return .steady
    }
}

// MARK: - Card depth (glass panels)

enum TaktCardElevation: Hashable {
    case low
    case mid
    case high

    fileprivate var shadowOpacity: Double {
        switch self {
        case .low: return 0.22
        case .mid: return 0.32
        case .high: return 0.42
        }
    }

    fileprivate var shadowRadius: CGFloat {
        switch self {
        case .low: return 4
        case .mid: return 6
        case .high: return 8
        }
    }

    fileprivate var shadowY: CGFloat {
        switch self {
        case .low: return 3
        case .mid: return 5
        case .high: return 7
        }
    }

    fileprivate var rimBlend: Double {
        switch self {
        case .low: return 0.0
        case .mid: return 0.04
        case .high: return 0.08
        }
    }
}

struct TaktCardModifier: ViewModifier {
    var elevation: TaktCardElevation = .mid
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let e = elevation
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.14 : 0.55),
                                        Color.white.opacity(colorScheme == .dark ? 0.04 : 0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(TaktTheme.cardBorder(for: colorScheme).opacity(0.85), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(e.rimBlend), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(e.shadowOpacity), radius: e.shadowRadius, x: 0, y: e.shadowY)
            )
    }
}

extension View {
    func taktCardStyle(elevation: TaktCardElevation = .mid) -> some View {
        modifier(TaktCardModifier(elevation: elevation))
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
                TaktTheme.rootBackdrop(for: colorScheme)
                    .ignoresSafeArea()
            )
    }
}
