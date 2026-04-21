import ActivityKit
import Foundation
import os.log
import WidgetKit

/// Pushes timer state to the App Group, Live Activities, and WidgetKit timelines.
@MainActor
enum TaktWidgetSyncService {
    private static let logger = Logger(subsystem: "com.presentationtimer.PresentationTimer", category: "TaktWidgetSync")

    private static var lastWidgetReload = Date.distantPast

    static func syncSession(engine: TimerEngine, preset: Preset?, sessionActive: Bool) {
        guard sessionActive, let preset else {
            endSessionVisuals()
            return
        }

        // Catch up wall-clock elapsed whenever we publish state (foreground timer, background, or Island).
        // Without this, `remainingSeconds` freezes while suspended and Dynamic Island drifts from the in-app timer.
        if engine.runState == .running {
            _ = engine.tick(now: Date())
        }

        let segTitle = engine.currentSegment?.title ?? preset.name
        let remaining = max(0, engine.remainingInSegment)
        let remainingInt = max(0, Int(remaining.rounded(.down)))
        let segmentEndDate: Date = {
            switch engine.runState {
            case .running:
                return Date().addingTimeInterval(remaining)
            case .paused, .completed:
                return Date().addingTimeInterval(remaining)
            case .idle:
                return Date()
            }
        }()

        let snap = TaktTimerSnapshot(
            updatedAt: .now,
            sessionActive: true,
            presetName: preset.name,
            segmentTitle: segTitle,
            remainingSeconds: remainingInt,
            segmentEndDate: segmentEndDate,
            segmentIndex: engine.currentSegmentIndex,
            segmentCount: max(engine.segments.count, 1),
            isPaused: engine.runState == .paused
        )
        snap.save()

        Task { @MainActor in
            await TaktLiveActivityController.shared.reconcileLiveActivity(
                engine: engine,
                snapshot: snap,
                presetName: preset.name
            )
        }

        if Date().timeIntervalSince(lastWidgetReload) > 15 {
            lastWidgetReload = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func endSessionVisuals() {
        Task { @MainActor in
            await TaktLiveActivityController.shared.endAllLiveActivities()
        }
        let idle = TaktTimerSnapshot(
            updatedAt: .now,
            sessionActive: false,
            presetName: "Takt",
            segmentTitle: "No active talk",
            remainingSeconds: 0,
            segmentEndDate: .now,
            segmentIndex: 0,
            segmentCount: 0,
            isPaused: false
        )
        idle.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Live Activity (must run on main; Activity.request is synchronous throws)

@MainActor
private final class TaktLiveActivityController {
    static let shared = TaktLiveActivityController()

    private let log = Logger(subsystem: "com.presentationtimer.PresentationTimer", category: "LiveActivity")
    private var cached: Activity<TaktTimerAttributes>?

    func endAllLiveActivities() async {
        cached = nil
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<TaktTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    func reconcileLiveActivity(
        engine: TimerEngine,
        snapshot: TaktTimerSnapshot,
        presetName: String
    ) async {
        guard #available(iOS 16.2, *) else { return }

        let auth = ActivityAuthorizationInfo()
        if !auth.areActivitiesEnabled {
            log.error("Live Activities are disabled (Settings → Takt → Live Activities, or system toggle).")
            return
        }

        let state = snapshot.contentState()
        let shouldShow: Bool = {
            switch engine.runState {
            case .running, .paused, .completed: return true
            case .idle: return false
            }
        }()

        if !shouldShow {
            await endAllLiveActivities()
            return
        }

        var existing = Activity<TaktTimerAttributes>.activities
        if existing.count > 1 {
            for extra in existing.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
            await Task.yield()
            existing = Activity<TaktTimerAttributes>.activities
        }
        if cached == nil {
            cached = existing.first
        }

        // Stale well past segment end so the system doesn’t clip updates; we push fresh state frequently.
        let stale = max(
            snapshot.segmentEndDate.addingTimeInterval(120),
            Date().addingTimeInterval(8 * 3600)
        )
        let content = ActivityContent(state: state, staleDate: stale)

        if cached == nil {
            do {
                cached = try Activity.request(
                    attributes: TaktTimerAttributes(presetName: presetName),
                    content: content,
                    pushType: nil
                )
                log.debug("Live Activity started.")
            } catch {
                log.error("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
                cached = nil
            }
        } else {
            await cached?.update(content)
        }
    }
}
