import SwiftUI

@main
struct PresentationTimerApp: App {
    @StateObject private var presetStore = PresetStore()
    @StateObject private var timerEngine = TimerEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(presetStore)
                .environmentObject(timerEngine)
        }
    }
}
