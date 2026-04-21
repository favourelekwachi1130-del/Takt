import Foundation

/// A single timed segment (e.g. one slide or section).
struct Segment: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    /// Duration in seconds; must be positive.
    var durationSeconds: TimeInterval
    /// Optional one-line cue for the speaker (shown on the live timer).
    var speakerNote: String

    init(id: UUID = UUID(), title: String, durationSeconds: TimeInterval, speakerNote: String = "") {
        self.id = id
        self.title = title
        self.durationSeconds = durationSeconds
        self.speakerNote = speakerNote
    }

    enum CodingKeys: String, CodingKey {
        case id, title, durationSeconds, speakerNote
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        durationSeconds = try c.decode(TimeInterval.self, forKey: .durationSeconds)
        speakerNote = try c.decodeIfPresent(String.self, forKey: .speakerNote) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(speakerNote, forKey: .speakerNote)
    }
}

/// Named preset containing an ordered list of segments.
struct Preset: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var segments: [Segment]
    var createdAt: Date
    /// Fraction of each segment (0.1...0.95) at which the first pacing cue fires. Default 0.75.
    var firstCueFraction: Double

    init(
        id: UUID = UUID(),
        name: String,
        segments: [Segment],
        createdAt: Date = .now,
        firstCueFraction: Double = 0.75
    ) {
        self.id = id
        self.name = name
        self.segments = segments
        self.createdAt = createdAt
        self.firstCueFraction = min(0.95, max(0.1, firstCueFraction))
    }

    enum CodingKeys: String, CodingKey {
        case id, name, segments, createdAt, firstCueFraction
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        segments = try c.decode([Segment].self, forKey: .segments)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        let raw = try c.decodeIfPresent(Double.self, forKey: .firstCueFraction) ?? 0.75
        firstCueFraction = min(0.95, max(0.1, raw))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(segments, forKey: .segments)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(firstCueFraction, forKey: .firstCueFraction)
    }
}

extension Preset {
    static let empty = Preset(name: "New preset", segments: [])

    /// Example preset for previews and first launch.
    static let sample = Preset(
        name: "Sample talk",
        segments: [
            Segment(title: "Intro", durationSeconds: 120),
            Segment(title: "Main idea", durationSeconds: 180),
            Segment(title: "Closing", durationSeconds: 90)
        ],
        firstCueFraction: 0.75
    )
}

