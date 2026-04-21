import SwiftUI

private struct LaunchPresentationKey: EnvironmentKey {
    static let defaultValue: ((Preset) -> Void)? = nil
}

private struct OpenTimerFullScreenKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
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
}
