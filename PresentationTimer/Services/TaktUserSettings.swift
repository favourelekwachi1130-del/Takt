import Foundation

/// Keys and typed accessors for user defaults used across the app.
enum TaktUserSettings {
    static let hapticIntensityKey = "taktHapticIntensity"
    static let cueSoundsEnabledKey = "taktCueSoundsEnabled"
    static let backgroundNotificationsEnabledKey = "taktBackgroundNotificationsEnabled"
    static let rehearsalModeKey = "taktRehearsalMode"
    static let startCountdownRitualKey = "taktStartCountdownRitual"
    static let displayNameKey = "taktDisplayName"
    static let profileSetupDoneKey = "taktProfileSetupDone"

    /// Fraction of segment length (0–1) where the first pacing cue fires.
    static let firstCueFractionKey = "taktFirstCueFraction"
    /// Fraction of segment length (0–1) where the second pacing cue fires (after the first).
    static let secondCueFractionKey = "taktSecondCueFraction"

    /// Allowed range for both cue sliders (fraction of segment).
    static let cueTimingMinFraction: Double = 0.1
    static let cueTimingMaxFraction: Double = 0.95
    /// Second cue must be at least this far after the first (fraction of segment).
    static let minimumCueGapFraction: Double = 0.02
    /// Extra space below the mini timer bar so it clears the tab bar / home indicator (points).
    static let miniBarExtraBottomKey = "taktMiniBarExtraBottom"

    /// `TaktAccentPalette` raw value — app-wide accent + derived ring colors.
    static let accentPaletteKey = "taktAccentPalette"

    /// `"top"` or `"bottom"` — which horizontal strip the mini bar lives in.
    static let miniBarBandKey = "taktMiniBarBand"
    /// Horizontal center position 0...1 within left/right margins (0.5 = centered).
    static let miniBarNormXKey = "taktMiniBarNormX"
    /// Vertical position 0...1 within the current band (0 = inner edge toward content, 1 = outer edge toward screen edge).
    static let miniBarNormYKey = "taktMiniBarNormY"

    enum HapticIntensity: String, CaseIterable {
        case light
        case medium
        case strong

        var displayName: String {
            switch self {
            case .light: return "Light"
            case .medium: return "Medium"
            case .strong: return "Strong"
            }
        }
    }

    static var hapticIntensity: HapticIntensity {
        let raw = UserDefaults.standard.string(forKey: hapticIntensityKey) ?? HapticIntensity.medium.rawValue
        return HapticIntensity(rawValue: raw) ?? .medium
    }

    static var cueSoundsEnabled: Bool {
        UserDefaults.standard.object(forKey: cueSoundsEnabledKey) as? Bool ?? false
    }

    static var backgroundNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: backgroundNotificationsEnabledKey) as? Bool ?? true
    }

    static var rehearsalModeEnabled: Bool {
        UserDefaults.standard.object(forKey: rehearsalModeKey) as? Bool ?? false
    }

    static var startCountdownRitualEnabled: Bool {
        UserDefaults.standard.object(forKey: startCountdownRitualKey) as? Bool ?? true
    }

    static func clampFirstCueFraction(_ value: Double) -> Double {
        min(cueTimingMaxFraction, max(cueTimingMinFraction, value))
    }

    /// Keeps the second cue after the first, within the global min/max range.
    static func clampSecondCueFraction(first: Double, proposed: Double) -> Double {
        let f = clampFirstCueFraction(first)
        let low = min(cueTimingMaxFraction, f + minimumCueGapFraction)
        return min(cueTimingMaxFraction, max(low, proposed))
    }

    /// Values used when a session runs (after clamping and ordering).
    static var resolvedFirstCueFraction: Double {
        let raw = UserDefaults.standard.object(forKey: firstCueFractionKey) as? Double ?? 0.75
        return clampFirstCueFraction(raw)
    }

    static var resolvedSecondCueFraction: Double {
        let first = resolvedFirstCueFraction
        let raw = UserDefaults.standard.object(forKey: secondCueFractionKey) as? Double ?? 0.9
        return clampSecondCueFraction(first: first, proposed: raw)
    }
}
