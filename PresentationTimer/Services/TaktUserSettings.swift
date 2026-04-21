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
}
