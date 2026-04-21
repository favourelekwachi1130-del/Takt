import ActivityKit
import Foundation
import WidgetKit

/// Pushes timer state to the App Group, Live Activities, and WidgetKit timelines.
@MainActor
enum TaktWidgetSyncService {
    private static var lastWidgetReload = Date.distantPast
    private static var liveActivity: Activity<TaktTimerAttributes>?

    static func syncSession(engine: TimerEngine, preset: Preset?, sessionActive: Bool) {
        guard sessionActive, let preset else {
            endSessionVisuals()
            return
        }

        let segTitle = engine.currentSegment?.title ?? preset.name
        let remaining = max(0, Int(engine.remainingInSegment.rounded(.down)))
        let snap = TaktTimerSnapshot(
            updatedAt: .now,
            sessionActive: true,
            presetName: preset.name,
            segmentTitle: segTitle,
            remainingSeconds: remaining,
            segmentIndex: engine.currentSegmentIndex,
            segmentCount: max(engine.segments.count, 1),
            isPaused: engine.runState == .paused
        )
        snap.save()

        Task { await reconcileLiveActivity(engine: engine, snapshot: snap, presetName: preset.name) }

        if Date().timeIntervalSince(lastWidgetReload) > 15 {
            lastWidgetReload = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func endSessionVisuals() {
        liveActivity = nil
        Task {
            if #available(iOS 16.2, *) {
                await endAllLiveActivities()
            }
        }
        let idle = TaktTimerSnapshot(
            updatedAt: .now,
            sessionActive: false,
            presetName: "Takt",
            segmentTitle: "No active talk",
            remainingSeconds: 0,
            segmentIndex: 0,
            segmentCount: 0,
            isPaused: false
        )
        idle.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func reconcileLiveActivity(
        engine: TimerEngine,
        snapshot: TaktTimerSnapshot,
        presetName: String
    ) async {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

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

        if liveActivity == nil {
            let attributes = TaktTimerAttributes(presetName: presetName)
            let content = ActivityContent(state: state, staleDate: nil)
            do {
                liveActivity = try await Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                liveActivity = nil
            }
        } else {
            await liveActivity?.update(using: state)
        }
    }

    @available(iOS 16.2, *)
    private static func endAllLiveActivities() async {
        for activity in Activity<TaktTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        liveActivity = nil
    }
}
