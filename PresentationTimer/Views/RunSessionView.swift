import SwiftUI

struct RunSessionView: View {
    let preset: Preset
    var onMinimize: () -> Void
    var onEnd: () -> Void
    var onRecordCompletion: () -> Void

    @EnvironmentObject private var timerEngine: TimerEngine
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    private let notifications = NotificationCueScheduler()

    @AppStorage(TaktUserSettings.startCountdownRitualKey) private var countdownRitualEnabled = true

    @State private var showSessionSummary = false
    @State private var summaryRehearsalRows: [SessionRehearsalRow] = []
    @State private var audioOutputLabel = AudioOutputDescriber.currentOutputLabel()

    @State private var prelaunch: Prelaunch = .live
    @State private var launchTask: Task<Void, Never>?

    private enum Prelaunch: Equatable {
        case countdown(Int)
        case go
        case live
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TaktTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    if timerEngine.runState == .completed {
                        completionBlock
                    } else {
                        activeTimerBlock
                    }
                }
                .padding(24)

                if prelaunch != .live {
                    prelaunchOverlay
                }
            }
            .navigationTitle("Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onMinimize()
                    } label: {
                        Label("Minimize", systemImage: "chevron.down")
                    }
                    .tint(TaktTheme.accent)
                    .disabled(prelaunch != .live)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("End talk", role: .destructive) {
                        Task { notifications.cancelAll() }
                        launchTask?.cancel()
                        onEnd()
                    }
                }
            }
        }
        .sheet(isPresented: $showSessionSummary) {
            SessionSummaryView(
                presetName: preset.name,
                segmentCount: preset.segments.count,
                wallSeconds: timerEngine.sessionWallElapsed(),
                plannedTotalSeconds: preset.segments.reduce(0) { $0 + $1.durationSeconds },
                rehearsalRows: TaktUserSettings.rehearsalModeEnabled ? summaryRehearsalRows : nil,
                onDone: {
                    showSessionSummary = false
                    onRecordCompletion()
                    Task { notifications.cancelAll() }
                    onEnd()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            CrashReporting.breadcrumb("run_session_appear")
            switch timerEngine.runState {
            case .running, .paused:
                prelaunch = .live
            case .idle, .completed:
                timerEngine.loadPreset(preset)
                if countdownRitualEnabled {
                    prelaunch = .countdown(3)
                    startLaunchSequence()
                } else {
                    prelaunch = .live
                    beginRunningSession()
                }
            }
        }
        .onDisappear {
            launchTask?.cancel()
            launchTask = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                let cues = timerEngine.tick(now: .now)
                handle(cues: cues)
                Task { await notifications.reschedule(engine: timerEngine) }
            } else if phase == .background {
                Task { await notifications.reschedule(engine: timerEngine) }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            audioOutputLabel = AudioOutputDescriber.currentOutputLabel()
            let cues = timerEngine.tick(now: .now)
            handle(cues: cues)
            if !cues.isEmpty {
                Task { await notifications.reschedule(engine: timerEngine) }
            }
        }
    }

    private var prelaunchOverlay: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.55 : 0.35)
                .ignoresSafeArea()

            Group {
                switch prelaunch {
                case .countdown(let n):
                    Text("\(n)")
                        .font(.system(size: 120, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 1.12).combined(with: .opacity),
                            removal: .scale(scale: 0.88).combined(with: .opacity)
                        ))
                case .go:
                    Text("Go")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundStyle(TaktTheme.ringGradient)
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                case .live:
                    EmptyView()
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: prelaunch)
        }
        .accessibilityHidden(true)
    }

    private func startLaunchSequence() {
        launchTask?.cancel()
        launchTask = Task { @MainActor in
            for n in (1...3).reversed() {
                guard !Task.isCancelled else { return }
                prelaunch = .countdown(n)
                HapticsService.countdownBeat()
                try? await Task.sleep(nanoseconds: 850_000_000)
            }
            guard !Task.isCancelled else { return }
            prelaunch = .go
            HapticsService.playFirstCue(intensity: TaktUserSettings.hapticIntensity)
            beginRunningSession()
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                prelaunch = .live
            }
        }
    }

    private func beginRunningSession() {
        timerEngine.start()
        Task {
            _ = await notifications.requestAuthorizationIfNeeded()
            await notifications.reschedule(engine: timerEngine)
        }
    }

    private var activeTimerBlock: some View {
        let phase = TaktTheme.sessionRingPhase(engine: timerEngine, preset: preset)
        let ringGradient = TaktTheme.sessionRingGradient(for: phase)

        return VStack(spacing: 20) {
            segmentTimelineStrip

            VStack(spacing: 6) {
                Text(currentTitle)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                if let next = nextSegmentTitle {
                    Text("Next: \(next)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                }

                let note = timerEngine.currentSegment?.speakerNote.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !note.isEmpty {
                    Text(note)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }

            phaseHint(for: phase)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12), lineWidth: 14)
                    .frame(width: 220, height: 220)
                Circle()
                    .trim(from: 0, to: timerEngine.progressInSegment)
                    .stroke(
                        ringGradient,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 220, height: 220)
                    .animation(.easeInOut(duration: 0.35), value: phase)
                VStack(spacing: 6) {
                    Text(timeRemainingLabel)
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(segmentProgressLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                }
            }
            .padding(.vertical, 8)

            Text(audioOutputLabel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))

            Group {
                if timerEngine.runState == .running {
                    Button {
                        timerEngine.pause()
                        Task { notifications.cancelAll() }
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(TaktTimerControlStyle(filled: true, gradient: TaktTheme.ringGradient))
                } else if timerEngine.runState == .paused {
                    Button {
                        timerEngine.resume()
                        Task { await notifications.reschedule(engine: timerEngine) }
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 22)
                    }
                    .buttonStyle(TaktTimerControlStyle(filled: true, gradient: ringGradient))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 16, y: 8)
                }
            }
        }
    }

    @ViewBuilder
    private func phaseHint(for phase: TaktTheme.SessionRingPhase) -> some View {
        let text: String = {
            switch phase {
            case .steady: return "In rhythm"
            case .pacing: return "Pacing zone — first cue fired"
            case .finalStretch: return "Home stretch — last segment"
            }
        }()
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(TaktTheme.cardBackground(for: colorScheme).opacity(0.9))
                    .overlay(Capsule().stroke(TaktTheme.cardBorder(for: colorScheme), lineWidth: 1))
            )
    }

    private var segmentTimelineStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(preset.segments.enumerated()), id: \.element.id) { index, seg in
                        let isCurrent = index == timerEngine.currentSegmentIndex
                        let isPast = index < timerEngine.currentSegmentIndex
                        Text(seg.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    isCurrent
                                        ? TaktTheme.accent.opacity(colorScheme == .dark ? 0.35 : 0.22)
                                        : TaktTheme.cardBackground(for: colorScheme)
                                )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isCurrent ? TaktTheme.accent.opacity(0.9) : TaktTheme.cardBorder(for: colorScheme),
                                        lineWidth: isCurrent ? 1.5 : 1
                                    )
                            )
                            .foregroundStyle(isPast ? TaktTheme.secondaryLabel(for: colorScheme) : .primary)
                            .opacity(isPast ? 0.65 : 1)
                            .id(index)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: timerEngine.currentSegmentIndex) { _, idx in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
    }

    private var completionBlock: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(TaktTheme.ringGradient)
                .symbolRenderingMode(.hierarchical)

            Text("Talk complete")
                .font(.title.weight(.bold))

            Text("Review your recap and save it to your stats.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))

            Button {
                summaryRehearsalRows = SessionRehearsalRow.build(
                    segments: preset.segments,
                    actuals: timerEngine.completedSegmentActualElapsed
                )
                showSessionSummary = true
            } label: {
                Text("Save & close")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(TaktTimerDoneStyle())
        }
    }

    private var currentTitle: String {
        timerEngine.currentSegment?.title ?? preset.name
    }

    private var nextSegmentTitle: String? {
        let next = timerEngine.currentSegmentIndex + 1
        guard preset.segments.indices.contains(next) else { return nil }
        return preset.segments[next].title
    }

    private var timeRemainingLabel: String {
        let r = timerEngine.remainingInSegment
        let m = Int(r) / 60
        let s = Int(r) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var segmentProgressLabel: String {
        let idx = timerEngine.currentSegmentIndex + 1
        let total = max(timerEngine.segments.count, 1)
        return "Segment \(idx) of \(total)"
    }

    private func handle(cues: [TimerCue]) {
        let hi = TaktUserSettings.hapticIntensity
        for cue in cues {
            switch cue {
            case .threeQuarter:
                HapticsService.playFirstCue(intensity: hi)
                CueSoundPlayer.playFirstCue()
            case .segmentEnd:
                HapticsService.playSegmentEnd(intensity: hi)
                CueSoundPlayer.playSegmentEnd()
            case .sessionComplete:
                HapticsService.playSessionComplete(intensity: hi)
                CueSoundPlayer.playSessionComplete()
                Task { notifications.cancelAll() }
            }
        }
    }
}

private struct TaktTimerControlStyle: ButtonStyle {
    var filled: Bool
    var gradient: LinearGradient = TaktTheme.ringGradient
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(filled ? (colorScheme == .dark ? Color.black : Color.white) : TaktTheme.accent)
            .background {
                if filled {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(gradient)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(TaktTheme.accent.opacity(filled ? 0 : 0.45), lineWidth: filled ? 0 : 1.5)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct TaktTimerDoneStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.black)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(TaktTheme.ringGradient)
                    .opacity(configuration.isPressed ? 0.88 : 1)
            )
    }
}

#Preview {
    RunSessionView(
        preset: .sample,
        onMinimize: {},
        onEnd: {},
        onRecordCompletion: {}
    )
    .environmentObject(TimerEngine())
}
