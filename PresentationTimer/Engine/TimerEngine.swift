import Foundation

/// Cues emitted by the engine (first pacing cue, end of segment, end of session).
enum TimerCue: Equatable, Sendable {
    case threeQuarter(segmentIndex: Int)
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
    /// First pacing cue threshold (e.g. 0.75 = 75% through segment).
    private(set) var firstCueFraction: Double = 0.75
    /// Wall-clock start of the current session (for summary stats).
    private(set) var sessionStartedAt: Date?
    /// Wall time spent in each completed segment (same order as `segments` indices), for rehearsal recap.
    @Published private(set) var completedSegmentActualElapsed: [TimeInterval] = []

    private var lastTickDate: Date?
    /// Per-segment flags so we only fire first cue and end once per segment.
    private var firedThreeQuarter: Set<Int> = []
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

    /// Loads segments and resets to idle (does not start).
    func loadPreset(_ preset: Preset) {
        stop(resetToIdle: true)
        firstCueFraction = min(0.95, max(0.1, preset.firstCueFraction))
        segments = preset.segments.filter { $0.durationSeconds > 0 }
        if segments.isEmpty {
            runState = .idle
            return
        }
        currentSegmentIndex = 0
        elapsedInCurrentSegment = 0
        firedThreeQuarter = []
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
        firedThreeQuarter = []
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
            firedThreeQuarter = []
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
            let thresholdFirst = firstCueFraction * duration

            if elapsedInCurrentSegment >= thresholdFirst, !firedThreeQuarter.contains(idx) {
                firedThreeQuarter.insert(idx)
                cues.append(.threeQuarter(segmentIndex: idx))
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

