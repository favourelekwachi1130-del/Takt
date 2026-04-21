import Foundation

/// Cues emitted by the engine (two pacing cues per segment, then segment end, then session end).
enum TimerCue: Equatable, Sendable {
    case firstPacing(segmentIndex: Int)
    case secondPacing(segmentIndex: Int)
    case segmentEnd(segmentIndex: Int)
    case sessionComplete
}

/// High-level run state for the presentation timer.
enum TimerRunState: Equatable, Sendable {
    case idle
    case running
    case paused
    case completed
}

/// Single source of truth for elapsed time, segment index, and cue thresholds.
///
/// Uses wall-clock deltas while running so background/foreground transitions stay consistent
/// when the app updates `tick(now:)` on resume.
final class TimerEngine: ObservableObject {
    @Published private(set) var runState: TimerRunState = .idle
    @Published private(set) var currentSegmentIndex: Int = 0
    /// Elapsed time within the current segment (may exceed duration until processed).
    @Published private(set) var elapsedInCurrentSegment: TimeInterval = 0
    /// Monotonic segment durations from the active preset.
    private(set) var segments: [Segment] = []
    /// First pacing cue threshold (fraction of segment length). From Settings.
    private(set) var firstCueFraction: Double = 0.75
    /// Second pacing cue threshold (fraction of segment length). From Settings.
    private(set) var secondCueFraction: Double = 0.9
    /// Wall-clock start of the current session (for summary stats).
    private(set) var sessionStartedAt: Date?
    /// Wall time spent in each completed segment (same order as `segments` indices), for rehearsal recap.
    @Published private(set) var completedSegmentActualElapsed: [TimeInterval] = []

    private var lastTickDate: Date?
    /// Per-segment flags so each cue fires once per segment.
    private var firedFirstPacing: Set<Int> = []
    private var firedSecondPacing: Set<Int> = []
    private var firedEnd: Set<Int> = []

    var currentSegment: Segment? {
        guard segments.indices.contains(currentSegmentIndex) else { return nil }
        return segments[currentSegmentIndex]
    }

    var currentSegmentDuration: TimeInterval {
        currentSegment?.durationSeconds ?? 0
    }

    var remainingInSegment: TimeInterval {
        max(0, currentSegmentDuration - elapsedInCurrentSegment)
    }

    /// 0...1 progress within current segment (clamped to current duration).
    var progressInSegment: Double {
        let d = currentSegmentDuration
        guard d > 0 else { return 1 }
        return min(1, max(0, elapsedInCurrentSegment / d))
    }

    /// Elapsed wall-clock time since `start()` for the active session.
    func sessionWallElapsed(at now: Date = .now) -> TimeInterval? {
        guard let s = sessionStartedAt else { return nil }
        return now.timeIntervalSince(s)
    }

    /// Loads segments and resets to idle (does not start). Cue positions come from Settings.
    func loadPreset(_ preset: Preset) {
        stop(resetToIdle: true)
        firstCueFraction = TaktUserSettings.resolvedFirstCueFraction
        secondCueFraction = TaktUserSettings.resolvedSecondCueFraction
        segments = preset.segments.filter { $0.durationSeconds > 0 }
        if segments.isEmpty {
            runState = .idle
            return
        }
        currentSegmentIndex = 0
        elapsedInCurrentSegment = 0
        firedFirstPacing = []
        firedSecondPacing = []
        firedEnd = []
        lastTickDate = nil
        sessionStartedAt = nil
        completedSegmentActualElapsed = []
        runState = .idle
    }

    /// Starts or restarts from the first segment.
    func start() {
        guard !segments.isEmpty else { return }
        currentSegmentIndex = 0
        elapsedInCurrentSegment = 0
        firedFirstPacing = []
        firedSecondPacing = []
        firedEnd = []
        completedSegmentActualElapsed = []
        lastTickDate = Date()
        sessionStartedAt = Date()
        runState = .running
    }

    func pause() {
        guard runState == .running else { return }
        consolidateElapsed(to: Date())
        lastTickDate = nil
        runState = .paused
    }

    func resume() {
        guard runState == .paused, !segments.isEmpty else { return }
        lastTickDate = Date()
        runState = .running
    }

    /// Stops and optionally clears to idle (no preset).
    func stop(resetToIdle: Bool = false) {
        lastTickDate = nil
        if resetToIdle {
            sessionStartedAt = nil
        }
        runState = resetToIdle || segments.isEmpty ? .idle : .completed
        if resetToIdle {
            segments = []
            currentSegmentIndex = 0
            elapsedInCurrentSegment = 0
            firedFirstPacing = []
            firedSecondPacing = []
            firedEnd = []
            completedSegmentActualElapsed = []
        }
    }

    /// Call from a 1 Hz timer or on scene phase active; returns emitted cues in order.
    func tick(now: Date = .now) -> [TimerCue] {
        guard runState == .running else { return [] }
        consolidateElapsed(to: now)

        var cues: [TimerCue] = []

        while runState == .running {
            guard let seg = currentSegment else {
                runState = .completed
                cues.append(.sessionComplete)
                return cues
            }

            let duration = seg.durationSeconds
            let idx = currentSegmentIndex
            let tFirst = firstCueFraction * duration
            let tSecond = secondCueFraction * duration
            let secondEffective = max(tSecond, tFirst + 0.001)

            if elapsedInCurrentSegment >= tFirst, !firedFirstPacing.contains(idx) {
                firedFirstPacing.insert(idx)
                cues.append(.firstPacing(segmentIndex: idx))
            }

            if elapsedInCurrentSegment >= secondEffective, !firedSecondPacing.contains(idx) {
                firedSecondPacing.insert(idx)
                cues.append(.secondPacing(segmentIndex: idx))
            }

            if elapsedInCurrentSegment < duration { break }

            if !firedEnd.contains(idx) {
                firedEnd.insert(idx)
                completedSegmentActualElapsed.append(elapsedInCurrentSegment)
                cues.append(.segmentEnd(segmentIndex: idx))
            }

            let overflow = elapsedInCurrentSegment - duration
            let next = idx + 1
            if next >= segments.count {
                elapsedInCurrentSegment = duration
                lastTickDate = nil
                runState = .completed
                cues.append(.sessionComplete)
                return cues
            }

            currentSegmentIndex = next
            elapsedInCurrentSegment = overflow
            lastTickDate = Date()
        }

        return cues
    }

    private func consolidateElapsed(to now: Date) {
        guard runState == .running, let last = lastTickDate else { return }
        let delta = now.timeIntervalSince(last)
        lastTickDate = now
        elapsedInCurrentSegment += delta
    }
}
