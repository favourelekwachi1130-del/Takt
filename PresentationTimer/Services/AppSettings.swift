import Foundation

/// User preferences stored in `UserDefaults`.
enum AppSettings {
    private static let skipDNDPromptKey = "skipDNDPrompt"

    static var skipDNDPrompt: Bool {
        get { UserDefaults.standard.bool(forKey: skipDNDPromptKey) }
        set { UserDefaults.standard.set(newValue, forKey: skipDNDPromptKey) }
    }
}
