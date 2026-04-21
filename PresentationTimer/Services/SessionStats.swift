import Foundation
import SwiftUI

/// Dashboard “completed talks” count. Stored in `UserDefaults` only (device-local).
///
/// iCloud Key-Value was removed here: it produced `SyncedDefaults` “No account” noise on simulators
/// without an Apple ID and did not justify the support burden. Talk **plans** still sync via CloudKit.
@MainActor
final class SessionStats: ObservableObject {
    private static let completedKey = "taktCompletedPresentations"

    @Published private(set) var completedPresentations: Int

    init() {
        completedPresentations = UserDefaults.standard.integer(forKey: Self.completedKey)
    }

    func recordPresentationCompleted() {
        completedPresentations += 1
        UserDefaults.standard.set(completedPresentations, forKey: Self.completedKey)
    }
}
