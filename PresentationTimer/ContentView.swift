import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var presetStore: PresetStore
    @EnvironmentObject private var timerEngine: TimerEngine
    @EnvironmentObject private var sessionStats: SessionStats
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.taktLaunchSplashDismissed) private var launchSplashDismissed

    @AppStorage("taktAppearance") private var appearanceRaw = "dark"
    @AppStorage(TaktUserSettings.accentPaletteKey) private var accentPaletteRaw = TaktAccentPalette.tangerine.rawValue
    @AppStorage(TaktUserSettings.miniBarExtraBottomKey) private var miniBarExtraBottom = 12.0

    /// Set whenever a talk is active (minimized or full-screen); drives the mini bar + engine binding.
    @State private var activeRunPreset: Preset?
    /// When non-nil, the live session UI is full-screen. When nil but `activeRunPreset` is set, user minimized.
    @State private var presentedRunSession: Preset?
    @State private var showDNDGate = false
    @State private var pendingRunPreset: Preset?
    @State private var selectedTab = 0

    private var preferredScheme: ColorScheme? {
        switch appearanceRaw {
        case "light": return .light
        case "system": return nil
        default: return .dark
        }
    }

    /// Mini bar only when a session exists and the user is not in the full-screen timer.
    private var showMiniTimer: Bool {
        activeRunPreset != nil && presentedRunSession == nil
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TaktHomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            PresetListView()
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(1)

            TaktSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .id(accentPaletteRaw)
        .tint(TaktTheme.accent)
        .background(TaktTheme.rootBackdrop(for: colorScheme).ignoresSafeArea())
        .overlay {
            if showMiniTimer, let preset = activeRunPreset {
                DraggableFloatingMiniBar(
                    presetName: preset.name,
                    remainingLabel: miniRemainingLabel,
                    segmentLabel: miniSegmentLabel,
                    ringPhase: TaktTheme.sessionRingPhase(engine: timerEngine, preset: preset),
                    isPaused: timerEngine.runState == .paused,
                    isCompleted: timerEngine.runState == .completed,
                    isIdleEngine: timerEngine.runState == .idle,
                    extraBottomLift: CGFloat(miniBarExtraBottom),
                    onOpen: {
                        presentedRunSession = activeRunPreset
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
                .allowsHitTesting(true)
            }
        }
        .preferredColorScheme(preferredScheme)
        .environment(\.taktHasActiveSession, activeRunPreset != nil)
        .environment(\.taktSelectTab, { index in
            selectedTab = index
        })
        .environment(\.taktLaunchPresentation, { preset in
            beginRunIfAllowed(with: preset)
        })
        .environment(\.taktOpenTimerFullScreen, {
            if let p = activeRunPreset {
                presentedRunSession = p
            }
        })
        .sheet(isPresented: $showDNDGate) {
            DNDGateView(isPresented: $showDNDGate) {
                guard let p = pendingRunPreset else { return }
                commitRun(with: p)
                pendingRunPreset = nil
            }
        }
        .fullScreenCover(item: $presentedRunSession, onDismiss: {
            // Minimize: `presentedRunSession` is already nil; keep `activeRunPreset` + engine until End talk.
        }) { preset in
            RunSessionView(
                preset: preset,
                onMinimize: { presentedRunSession = nil },
                onEnd: {
                    endRun()
                },
                onRecordCompletion: {
                    sessionStats.recordPresentationCompleted()
                }
            )
        }
        .onAppear {
            if launchSplashDismissed {
                runPostSplashForegroundWork()
            }
        }
        .onChange(of: launchSplashDismissed) { _, dismissed in
            guard dismissed else { return }
            runPostSplashForegroundWork()
        }
        .onChange(of: accentPaletteRaw) { _, _ in
            TaktAppIconSync.applyCurrentPalette()
        }
        .onChange(of: timerEngine.runState) { _, new in
            guard let p = activeRunPreset else { return }
            switch new {
            case .running, .paused, .completed:
                TaktWidgetSyncService.syncSession(engine: timerEngine, preset: p, sessionActive: true)
            case .idle:
                break
            }
        }
        .onChange(of: presentedRunSession) { _, _ in
            guard let p = activeRunPreset else { return }
            TaktWidgetSyncService.syncSession(engine: timerEngine, preset: p, sessionActive: true)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                presetStore.refreshFromCloudIfNeeded()
            }
            guard let p = activeRunPreset else { return }
            switch phase {
            case .active:
                if presentedRunSession == nil {
                    _ = timerEngine.tick(now: Date())
                }
                TaktWidgetSyncService.syncSession(engine: timerEngine, preset: p, sessionActive: true)
            case .inactive, .background:
                TaktWidgetSyncService.syncSession(engine: timerEngine, preset: p, sessionActive: true)
            @unknown default:
                break
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard activeRunPreset != nil else { return }
            if presentedRunSession == nil {
                _ = timerEngine.tick(now: Date())
            }
            TaktWidgetSyncService.syncSession(
                engine: timerEngine,
                preset: activeRunPreset,
                sessionActive: true
            )
        }
    }

    /// Icon sync + shortcuts + widget state — runs after the launch overlay is gone so cold start matches the first frame users see.
    private func runPostSplashForegroundWork() {
        TaktAppIconSync.applyCurrentPalette()
        processPendingShortcutIntent()
        if let p = activeRunPreset {
            TaktWidgetSyncService.syncSession(
                engine: timerEngine,
                preset: p,
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
        presentedRunSession = preset
    }

    private func endRun() {
        timerEngine.stop(resetToIdle: true)
        activeRunPreset = nil
        presentedRunSession = nil
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
