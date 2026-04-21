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

    /// Schedules one pending notification for the nearest future cue (first pacing, second pacing, or segment end).
    func reschedule(engine: TimerEngine) async {
        cancelAll()
        guard TaktUserSettings.backgroundNotificationsEnabled else { return }
        guard engine.runState == .running else { return }

        let segments = engine.segments
        guard !segments.isEmpty, segments.indices.contains(engine.currentSegmentIndex) else { return }

        let idx = engine.currentSegmentIndex
        let seg = segments[idx]
        let d = seg.durationSeconds
        let elapsed = engine.elapsedInCurrentSegment

        let f1 = engine.firstCueFraction * d
        let f2 = engine.secondCueFraction * d

        enum NextKind {
            case firstPacing
            case secondPacing
            case segmentEnd
        }

        var candidates: [(TimeInterval, NextKind)] = []

        if elapsed < f1 - 0.01 {
            candidates.append((max(0, f1 - elapsed), .firstPacing))
        }
        if f2 > f1 + 0.01, elapsed < f2 - 0.01 {
            candidates.append((max(0, f2 - elapsed), .secondPacing))
        }
        if elapsed < d - 0.01 {
            candidates.append((max(0, d - elapsed), .segmentEnd))
        }

        guard let best = candidates.filter({ $0.0 > 0.5 }).min(by: { $0.0 < $1.0 }) else {
            return
        }

        let interval = best.0
        let kind = best.1

        let content = UNMutableNotificationContent()
        content.title = seg.title
        switch kind {
        case .firstPacing:
            content.body = "First pacing cue — first stretch of this segment is done."
        case .secondPacing:
            content.body = "Second pacing cue — almost at the end of this segment."
        case .segmentEnd:
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
