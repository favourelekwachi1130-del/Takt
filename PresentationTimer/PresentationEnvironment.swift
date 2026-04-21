import SwiftUI

private struct LaunchPresentationKey: EnvironmentKey {
    static let defaultValue: ((Preset) -> Void)? = nil
}

private struct OpenTimerFullScreenKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct SelectTabKey: EnvironmentKey {
    static let defaultValue: ((Int) -> Void)? = nil
}

private struct HasActiveSessionKey: EnvironmentKey {
    static let defaultValue = false
}

/// `false` while the branded launch overlay is visible; `true` after it dismisses. Default `true` (e.g. previews).
private struct LaunchSplashDismissedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Starts the DND flow (if needed) and opens the full-screen timer for this preset.
    var taktLaunchPresentation: ((Preset) -> Void)? {
        get { self[LaunchPresentationKey.self] }
        set { self[LaunchPresentationKey.self] = newValue }
    }

    /// Brings the running timer back to full screen (e.g. from mini player).
    var taktOpenTimerFullScreen: (() -> Void)? {
        get { self[OpenTimerFullScreenKey.self] }
        set { self[OpenTimerFullScreenKey.self] = newValue }
    }

    /// Switch main tab: 0 = Home, 1 = Plans, 2 = Settings.
    var taktSelectTab: ((Int) -> Void)? {
        get { self[SelectTabKey.self] }
        set { self[SelectTabKey.self] = newValue }
    }

    /// `true` when a talk is bound to the shared session (`ContentView.activeRunPreset`).
    var taktHasActiveSession: Bool {
        get { self[HasActiveSessionKey.self] }
        set { self[HasActiveSessionKey.self] = newValue }
    }

    /// Use to defer work until after `TaktLaunchSplashView` finishes (icon sync, shortcuts).
    var taktLaunchSplashDismissed: Bool {
        get { self[LaunchSplashDismissedKey.self] }
        set { self[LaunchSplashDismissedKey.self] = newValue }
    }
}
