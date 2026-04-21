import SwiftUI

/// Named accent presets (default **tangerine** uses the `TaktAccent` asset). Drives rings, buttons, and hero undertones app-wide.
enum TaktAccentPalette: String, CaseIterable, Identifiable {
    case tangerine
    case coral
    case mint
    case sky
    case violet
    case rose

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tangerine: return "Tangerine"
        case .coral: return "Coral"
        case .mint: return "Mint"
        case .sky: return "Sky"
        case .violet: return "Violet"
        case .rose: return "Rose"
        }
    }

    static func resolved() -> Self {
        let raw = UserDefaults.standard.string(forKey: TaktUserSettings.accentPaletteKey) ?? Self.tangerine.rawValue
        return Self(rawValue: raw) ?? .tangerine
    }

    /// Asset-catalog alternate app icon set name. `nil` = primary **AppIcon** (tangerine).
    var alternateAppIconName: String? {
        switch self {
        case .tangerine: return nil
        case .coral: return "AppIconCoral"
        case .mint: return "AppIconMint"
        case .sky: return "AppIconSky"
        case .violet: return "AppIconViolet"
        case .rose: return "AppIconRose"
        }
    }

    /// Primary accent — tabs, filled controls, steady ring.
    var primary: Color {
        switch self {
        case .tangerine:
            return Color("TaktAccent")
        case .coral:
            return Color(red: 0.96, green: 0.36, blue: 0.31)
        case .mint:
            return Color(red: 0.15, green: 0.78, blue: 0.56)
        case .sky:
            return Color(red: 0.22, green: 0.52, blue: 0.98)
        case .violet:
            return Color(red: 0.55, green: 0.38, blue: 0.98)
        case .rose:
            return Color(red: 0.98, green: 0.32, blue: 0.52)
        }
    }

    /// Secondary emphasis (e.g. a second stat tile) — distinct from `primary` but same family.
    var secondary: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.86, green: 0.44, blue: 0.18)
        case .coral:
            return Color(red: 0.98, green: 0.52, blue: 0.42)
        case .mint:
            return Color(red: 0.28, green: 0.88, blue: 0.65)
        case .sky:
            return Color(red: 0.45, green: 0.68, blue: 1.0)
        case .violet:
            return Color(red: 0.72, green: 0.58, blue: 1.0)
        case .rose:
            return Color(red: 1.0, green: 0.48, blue: 0.68)
        }
    }

    /// Mid-session pacing ring — brighter than steady.
    var ringPacing: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.93, green: 0.48, blue: 0.14)
        case .coral:
            return Color(red: 1.0, green: 0.55, blue: 0.38)
        case .mint:
            return Color(red: 0.35, green: 0.92, blue: 0.62)
        case .sky:
            return Color(red: 0.45, green: 0.72, blue: 1.0)
        case .violet:
            return Color(red: 0.72, green: 0.55, blue: 1.0)
        case .rose:
            return Color(red: 1.0, green: 0.48, blue: 0.62)
        }
    }

    /// Final segment ring — deeper, muted.
    var ringDeep: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.48, green: 0.22, blue: 0.10)
        case .coral:
            return Color(red: 0.62, green: 0.22, blue: 0.18)
        case .mint:
            return Color(red: 0.08, green: 0.42, blue: 0.30)
        case .sky:
            return Color(red: 0.12, green: 0.28, blue: 0.55)
        case .violet:
            return Color(red: 0.32, green: 0.18, blue: 0.58)
        case .rose:
            return Color(red: 0.58, green: 0.14, blue: 0.34)
        }
    }

    /// Flat fill for rasterized share cards (solid color; materials don’t render reliably in `ImageRenderer`).
    var heroShareCardFill: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.11, green: 0.08, blue: 0.07)
        case .coral:
            return Color(red: 0.14, green: 0.06, blue: 0.06)
        case .mint:
            return Color(red: 0.05, green: 0.11, blue: 0.08)
        case .sky:
            return Color(red: 0.06, green: 0.08, blue: 0.12)
        case .violet:
            return Color(red: 0.08, green: 0.06, blue: 0.12)
        case .rose:
            return Color(red: 0.12, green: 0.05, blue: 0.08)
        }
    }
}
