import SwiftUI

@main
struct PresentationTimerApp: App {
    @StateObject private var presetStore = PresetStore()
    @StateObject private var timerEngine = TimerEngine()
    @StateObject private var sessionStats = SessionStats()
    @State private var showLaunchSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(presetStore)
                    .environmentObject(timerEngine)
                    .environmentObject(sessionStats)
                    .environment(\.taktLaunchSplashDismissed, !showLaunchSplash)
                    .onOpenURL { url in
                        Self.handleIncomingPresetURL(url, presetStore: presetStore)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                        guard let url = activity.webpageURL else { return }
                        Self.handleIncomingPresetURL(url, presetStore: presetStore)
                    }

                if showLaunchSplash {
                    TaktLaunchSplashView {
                        withAnimation(.easeInOut(duration: 0.48)) {
                            showLaunchSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }

    /// Universal Links (`https://takt-app.org/import?p=…`) and custom scheme (`takt://import?p=…`).
    private static func handleIncomingPresetURL(_ url: URL, presetStore: PresetStore) {
        guard let imported = try? TaktPresetURL.importPreset(from: url) else { return }
        presetStore.upsert(imported)
    }
}
