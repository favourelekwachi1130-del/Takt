import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var presetStore: PresetStore
    @EnvironmentObject private var timerEngine: TimerEngine
    @EnvironmentObject private var sessionStats: SessionStats
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("taktAppearance") private var appearanceRaw = "dark"

    @State private var activeRunPreset: Preset?
    @State private var showRunFullScreen = false
    @State private var showDNDGate = false
    @State private var pendingRunPreset: Preset?

    private var preferredScheme: ColorScheme? {
        switch appearanceRaw {
        case "light": return .light
        case "system": return nil
        default: return .dark
        }
    }

    private var showMiniTimer: Bool {
        guard activeRunPreset != nil, !showRunFullScreen else { return false }
        switch timerEngine.runState {
        case .running, .paused, .completed:
            return true
        case .idle:
            return false
        }
    }

    var body: some View {
        TabView {
            TaktHomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            PresetListView()
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.rectangle.fill")
                }

            TaktSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(TaktTheme.accent)
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if showMiniTimer, let preset = activeRunPreset {
                MiniTimerBar(
                    presetName: preset.name,
                    remainingLabel: miniRemainingLabel,
                    segmentLabel: miniSegmentLabel,
                    ringPhase: TaktTheme.sessionRingPhase(engine: timerEngine, preset: preset),
                    isPaused: timerEngine.runState == .paused,
                    isCompleted: timerEngine.runState == .completed,
                    onOpen: { showRunFullScreen = true }
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(preferredScheme)
        .environment(\.taktLaunchPresentation, { preset in
            beginRunIfAllowed(with: preset)
        })
        .environment(\.taktOpenTimerFullScreen, {
            if activeRunPreset != nil {
                showRunFullScreen = true
            }
        })
        .sheet(isPresented: $showDNDGate) {
            DNDGateView(isPresented: $showDNDGate) {
                guard let p = pendingRunPreset else { return }
                commitRun(with: p)
                pendingRunPreset = nil
            }
        }
        .fullScreenCover(isPresented: $showRunFullScreen, onDismiss: {
            // Minimize: keep engine + activeRunPreset; only full `End talk` clears those.
        }) {
            if let p = activeRunPreset {
                RunSessionView(
                    preset: p,
                    onMinimize: { showRunFullScreen = false },
                    onEnd: {
                        endRun()
                    },
                    onRecordCompletion: {
                        sessionStats.recordPresentationCompleted()
                    }
                )
            }
        }
        .onAppear {
            processPendingShortcutIntent()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, activeRunPreset != nil else { return }
            // Catch up wall time after backgrounding (timers may pause).
            if !showRunFullScreen {
                _ = timerEngine.tick(now: Date())
            }
            TaktWidgetSyncService.syncSession(
                engine: timerEngine,
                preset: activeRunPreset,
                sessionActive: true
            )
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard activeRunPreset != nil else { return }
            // `RunSessionView` owns ticks while full screen; otherwise the engine would stall when minimized.
            if !showRunFullScreen {
                _ = timerEngine.tick(now: Date())
            }
            TaktWidgetSyncService.syncSession(
                engine: timerEngine,
                preset: activeRunPreset,
                sessionActive: true
            )
        }
    }

    private func processPendingShortcutIntent() {
        guard let id = TaktPendingShortcut.consumePendingPresetId(),
              let preset = presetStore.presets.first(where: { $0.id == id }) else { return }
        beginRunIfAllowed(with: preset)
    }

    private var miniRemainingLabel: String {
        let r = timerEngine.remainingInSegment
        let m = Int(r) / 60
        let s = Int(r) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var miniSegmentLabel: String {
        let idx = timerEngine.currentSegmentIndex + 1
        let total = max(timerEngine.segments.count, 1)
        return "Segment \(idx) of \(total)"
    }

    private func beginRunIfAllowed(with preset: Preset) {
        guard !preset.segments.isEmpty else { return }
        if AppSettings.skipDNDPrompt {
            commitRun(with: preset)
        } else {
            pendingRunPreset = preset
            showDNDGate = true
        }
    }

    private func commitRun(with preset: Preset) {
        timerEngine.loadPreset(preset)
        activeRunPreset = preset
        showRunFullScreen = true
    }

    private func endRun() {
        timerEngine.stop(resetToIdle: true)
        activeRunPreset = nil
        showRunFullScreen = false
        TaktWidgetSyncService.endSessionVisuals()
    }
}

#Preview {
    ContentView()
        .environmentObject(PresetStore())
        .environmentObject(TimerEngine())
        .environmentObject(SessionStats())
        .preferredColorScheme(.dark)
}
