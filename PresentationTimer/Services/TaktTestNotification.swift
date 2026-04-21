import Foundation
import UserNotifications

enum TaktTestNotification {
    /// Schedules a lock-screen notification in ~1s so the user can verify Focus / notification settings.
    static func scheduleTestAlert() async {
        let center = UNUserNotificationCenter.current()
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return
        }
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Takt test alert"
        content.body = "If you see this, notifications can reach you when Takt is in the background."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(
            identifier: "takt.test.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(req)
    }
}
