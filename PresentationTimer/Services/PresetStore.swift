import Foundation
import SwiftUI

/// Persists presets as JSON in Application Support.
@MainActor
final class PresetStore: ObservableObject {
    @Published private(set) var presets: [Preset] = []

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("PresentationTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("presets.json")
        load()
        if presets.isEmpty {
            presets = [.sample]
            save()
        }
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            presets = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            presets = try decoder.decode([Preset].self, from: data)
        } catch {
            presets = []
        }
    }

    func save() {
        do {
            let data = try encoder.encode(presets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best-effort persistence; surface in UI if needed later
        }
    }

    func upsert(_ preset: Preset) {
        if let i = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[i] = preset
        } else {
            presets.append(preset)
        }
        save()
    }

    func delete(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        save()
    }

    func delete(id: UUID) {
        presets.removeAll { $0.id == id }
        save()
    }

    /// Encoded JSON data for share sheet export.
    func exportData(for preset: Preset) throws -> Data {
        try encoder.encode(preset)
    }

    func importPreset(from data: Data) throws {
        let p = try decoder.decode(Preset.self, from: data)
        upsert(p)
    }
}
