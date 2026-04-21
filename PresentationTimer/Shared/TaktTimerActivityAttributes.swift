import ActivityKit
import Foundation

// MARK: - Live Activity + lock screen (shared across app & widget extension)

/// Lightweight preset row for Shortcuts / widget (mirrored from the main store).
public struct TaktSharedPresetSummary: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

/// Snapshot written by the app on each tick; read by widgets and used for Live Activity updates.
public struct TaktTimerSnapshot: Codable, Sendable, Hashable {
    public var updatedAt: Date
    public var sessionActive: Bool
    public var presetName: String
    public var segmentTitle: String
    public var remainingSeconds: Int
    /// Wall-clock instant when the current segment ends; drives Live Activity / Dynamic Island `Text(.timer)` between app updates.
    public var segmentEndDate: Date
    public var segmentIndex: Int
    public var segmentCount: Int
    public var isPaused: Bool

    public static let storageKey = "takt.timer.snapshot"

    public static let placeholder = TaktTimerSnapshot(
        updatedAt: .now,
        sessionActive: false,
        presetName: "Takt",
        segmentTitle: "Open the app",
        remainingSeconds: 0,
        segmentEndDate: .now,
        segmentIndex: 0,
        segmentCount: 0,
        isPaused: false
    )

    public init(
        updatedAt: Date,
        sessionActive: Bool,
        presetName: String,
        segmentTitle: String,
        remainingSeconds: Int,
        segmentEndDate: Date,
        segmentIndex: Int,
        segmentCount: Int,
        isPaused: Bool
    ) {
        self.updatedAt = updatedAt
        self.sessionActive = sessionActive
        self.presetName = presetName
        self.segmentTitle = segmentTitle
        self.remainingSeconds = remainingSeconds
        self.segmentEndDate = segmentEndDate
        self.segmentIndex = segmentIndex
        self.segmentCount = segmentCount
        self.isPaused = isPaused
    }

    enum CodingKeys: String, CodingKey {
        case updatedAt, sessionActive, presetName, segmentTitle, remainingSeconds, segmentEndDate
        case segmentIndex, segmentCount, isPaused
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        sessionActive = try c.decode(Bool.self, forKey: .sessionActive)
        presetName = try c.decode(String.self, forKey: .presetName)
        segmentTitle = try c.decode(String.self, forKey: .segmentTitle)
        remainingSeconds = try c.decode(Int.self, forKey: .remainingSeconds)
        segmentIndex = try c.decode(Int.self, forKey: .segmentIndex)
        segmentCount = try c.decode(Int.self, forKey: .segmentCount)
        isPaused = try c.decode(Bool.self, forKey: .isPaused)
        if let end = try c.decodeIfPresent(Date.self, forKey: .segmentEndDate) {
            segmentEndDate = end
        } else {
            segmentEndDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(sessionActive, forKey: .sessionActive)
        try c.encode(presetName, forKey: .presetName)
        try c.encode(segmentTitle, forKey: .segmentTitle)
        try c.encode(remainingSeconds, forKey: .remainingSeconds)
        try c.encode(segmentEndDate, forKey: .segmentEndDate)
        try c.encode(segmentIndex, forKey: .segmentIndex)
        try c.encode(segmentCount, forKey: .segmentCount)
        try c.encode(isPaused, forKey: .isPaused)
    }

    public func save() {
        guard let d = TaktAppGroup.defaultsIfAvailable else { return }
        guard let data = try? JSONEncoder().encode(self) else { return }
        d.set(data, forKey: Self.storageKey)
    }

    public static func load() -> TaktTimerSnapshot? {
        guard let d = TaktAppGroup.defaultsIfAvailable,
              let data = d.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(TaktTimerSnapshot.self, from: data)
    }
}

public enum TaktSharedPresetIndex {
    public static let storageKey = "takt.presets.index"

    public static func save(_ presets: [TaktSharedPresetSummary]) {
        guard let d = TaktAppGroup.defaultsIfAvailable else { return }
        guard let data = try? JSONEncoder().encode(presets) else { return }
        d.set(data, forKey: storageKey)
    }

    public static func load() -> [TaktSharedPresetSummary] {
        guard let d = TaktAppGroup.defaultsIfAvailable,
              let data = d.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([TaktSharedPresetSummary].self, from: data)) ?? []
    }
}

public struct TaktTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var segmentTitle: String
        public var remainingSeconds: Int
        /// Target end time for the current segment; used with `Text(_, style: .timer)` on Dynamic Island / lock screen.
        public var segmentEndDate: Date
        public var segmentIndex: Int
        public var segmentCount: Int
        public var isPaused: Bool

        public init(
            segmentTitle: String,
            remainingSeconds: Int,
            segmentEndDate: Date,
            segmentIndex: Int,
            segmentCount: Int,
            isPaused: Bool
        ) {
            self.segmentTitle = segmentTitle
            self.remainingSeconds = remainingSeconds
            self.segmentEndDate = segmentEndDate
            self.segmentIndex = segmentIndex
            self.segmentCount = segmentCount
            self.isPaused = isPaused
        }
    }

    public var presetName: String

    public init(presetName: String) {
        self.presetName = presetName
    }
}

public extension TaktTimerSnapshot {
    func contentState() -> TaktTimerAttributes.ContentState {
        TaktTimerAttributes.ContentState(
            segmentTitle: segmentTitle,
            remainingSeconds: remainingSeconds,
            segmentEndDate: segmentEndDate,
            segmentIndex: segmentIndex,
            segmentCount: segmentCount,
            isPaused: isPaused
        )
    }
}
