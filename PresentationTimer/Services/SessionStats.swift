import Foundation
import SwiftUI

/// Persisted counts for dashboard stats (local-only).
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
