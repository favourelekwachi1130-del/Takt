import Foundation

/// Shared App Group for the main app, widget extension, and intents.
public enum TaktAppGroup {
    public static let identifier = "group.com.presentationtimer.shared"

    /// Returns the suite when App Groups are enabled; otherwise `nil` (writes are skipped).
    public static var defaultsIfAvailable: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
}

/// Shortcuts / App Intents stash a preset id here; the main app consumes it on launch.
public enum TaktPendingShortcut {
    private static let pendingPresetIdKey = "takt.shortcut.pendingPresetUUID"

    public static func setPendingPreset(id: UUID) {
        TaktAppGroup.defaultsIfAvailable?.set(id.uuidString, forKey: pendingPresetIdKey)
    }

    public static func consumePendingPresetId() -> UUID? {
        guard let d = TaktAppGroup.defaultsIfAvailable,
              let s = d.string(forKey: pendingPresetIdKey) else { return nil }
        d.removeObject(forKey: pendingPresetIdKey)
        return UUID(uuidString: s)
    }
}
