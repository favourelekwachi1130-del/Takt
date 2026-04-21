import Foundation
import UserNotifications

/// Schedules local notifications for the next upcoming cue while the timer may be backgrounded.
final class NotificationCueScheduler {
    private let center = UNUserNotificationCenter.current()
    private static let nextCueId = "presentationTimer.nextCue"

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        default:
            return false
        }
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.nextCueId])
    }

    /// Schedules one pending notification for the nearest future cue (75% or segment end) from current engine state.
    func reschedule(engine: TimerEngine) async {
        cancelAll()
        guard engine.runState == .running else { return }

        let segments = engine.segments
        guard !segments.isEmpty, segments.indices.contains(engine.currentSegmentIndex) else { return }

        let idx = engine.currentSegmentIndex
        let seg = segments[idx]
        let d = seg.durationSeconds
        let elapsed = engine.elapsedInCurrentSegment

        let to75 = max(0, 0.75 * d - elapsed)
        let toEnd = max(0, d - elapsed)

        let nextInterval: TimeInterval?
        let isThreeQuarter: Bool

        if to75 > 0, toEnd > 0 {
            if to75 < toEnd {
                nextInterval = to75
                isThreeQuarter = true
            } else {
                nextInterval = toEnd
                isThreeQuarter = false
            }
        } else if to75 > 0 {
            nextInterval = to75
            isThreeQuarter = true
        } else if toEnd > 0 {
            nextInterval = toEnd
            isThreeQuarter = false
        } else {
            nextInterval = nil
            isThreeQuarter = false
        }

        guard let interval = nextInterval, interval > 0.5 else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = seg.title
        if isThreeQuarter {
            content.body = "About three-quarters through this segment."
        } else {
            content.body = "Segment time is ending."
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let req = UNNotificationRequest(identifier: Self.nextCueId, content: content, trigger: trigger)
        do {
            try await center.add(req)
        } catch {
            // Ignore scheduling failures
        }
    }
}
