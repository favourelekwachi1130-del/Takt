import Foundation
import OSLog

/// Pluggable crash/analytics boundary. Default implementation logs to unified logging only.
///
/// **Optional cloud (deferred):** Swap the implementation for Firebase Crashlytics, Sentry, or
/// another provider without changing call sites. See [docs/OptionalCloud.md](docs/OptionalCloud.md).
enum CrashReporting {
    private static let log = Logger(subsystem: "com.presentationtimer.PresentationTimer", category: "CrashReporting")

    static func recordError(_ error: Error, userInfo: [String: String]? = nil) {
        log.error("recorded: \(String(describing: error), privacy: .public) extra: \(String(describing: userInfo), privacy: .public)")
    }

    static func breadcrumb(_ message: String) {
        log.debug("breadcrumb: \(message, privacy: .public)")
    }
}
