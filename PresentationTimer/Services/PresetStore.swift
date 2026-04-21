import Foundation
import SwiftUI

/// Persists presets as JSON in the App Group (widgets / intents) and syncs a copy to **iCloud** (private CloudKit DB).
@MainActor
final class PresetStore: ObservableObject {
    @Published private(set) var presets: [Preset] = []

    private let fileURL: URL
    private let legacyFileURL: URL
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
        legacyFileURL = Self.legacyApplicationSupportFileURL()
        fileURL = Self.appGroupFileURL() ?? legacyFileURL
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        migrateLegacyIfNeeded()
        load()
        if presets.isEmpty {
            presets = [.sample]
            save()
        } else {
            publishSharedPresetIndex()
        }
        Task { await refreshFromCloudIfNeededAsync() }
    }

    /// Call when returning to foreground so another device’s changes can appear.
    func refreshFromCloudIfNeeded() {
        Task { await refreshFromCloudIfNeededAsync() }
    }

    private func refreshFromCloudIfNeededAsync() async {
        guard await TaktICloudPresetsSync.isAvailableForSync() else { return }
        let localMod = fileModificationDate() ?? .distantPast

        do {
            if let remote = try await TaktICloudPresetsSync.fetchPresetsPayload() {
                if remote.modified > localMod {
                    let decoded = try decoder.decode([Preset].self, from: remote.data)
                    presets = decoded.isEmpty ? [.sample] : decoded
                    try encoder.encode(presets).write(to: fileURL, options: .atomic)
                    publishSharedPresetIndex()
                } else if localMod > remote.modified, !presets.isEmpty {
                    let data = try encoder.encode(presets)
                    try await TaktICloudPresetsSync.savePresetsPayload(data)
                }
            } else if !presets.isEmpty {
                let data = try encoder.encode(presets)
                try await TaktICloudPresetsSync.savePresetsPayload(data)
            }
        } catch {
            // Offline or transient CloudKit error — local data remains authoritative.
        }
    }

    private func fileModificationDate() -> Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let d = attrs[.modificationDate] as? Date else { return nil }
        return d
    }

    private static func appGroupFileURL() -> URL? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: TaktAppGroup.identifier) else {
            return nil
        }
        return base
            .appendingPathComponent("Library/Application Support/PresentationTimer", isDirectory: true)
            .appendingPathComponent("presets.json")
    }

    private static func legacyApplicationSupportFileURL() -> URL {
        let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("PresentationTimer-fallback", isDirectory: true)
            .appendingPathComponent("presets.json")
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return fallback
        }
        return base
            .appendingPathComponent("PresentationTimer", isDirectory: true)
            .appendingPathComponent("presets.json")
    }

    private func migrateLegacyIfNeeded() {
        let fm = FileManager.default
        guard fileURL != legacyFileURL,
              !fm.fileExists(atPath: fileURL.path),
              fm.fileExists(atPath: legacyFileURL.path) else { return }
        try? fm.copyItem(at: legacyFileURL, to: fileURL)
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
            publishSharedPresetIndex()
            Task { await pushToCloud(data) }
        } catch {
            // Best-effort persistence
        }
    }

    private func pushToCloud(_ data: Data) async {
        guard await TaktICloudPresetsSync.isAvailableForSync() else { return }
        do {
            try await TaktICloudPresetsSync.savePresetsPayload(data)
        } catch {
            // Retry on next foreground / launch
        }
    }

    private func publishSharedPresetIndex() {
        let rows = presets.map { TaktSharedPresetSummary(id: $0.id, name: $0.name) }
        TaktSharedPresetIndex.save(rows)
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

    /// Writes **JSON** to a `.json` file under **temporaryDirectory** so Share / Save to Files shows a real document type, not “data”.
    func exportJSONFileURL(for preset: Preset) throws -> URL {
        let base = Self.sanitizeFilename(preset.name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(base).json")
        let data = try exportData(for: preset)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Writes a Markdown file with a Mermaid **Gantt** timeline to **temporaryDirectory** for sharing (e.g. Save to Files).
    func exportMermaidGanttFileURL(for preset: Preset) throws -> URL {
        let base = Self.sanitizeFilename(preset.name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(base)-timeline.md")
        let doc = TaktPresetMermaid.ganttMarkdownDocument(for: preset)
        try doc.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/:<>\"\\|?*\u{0000}")
        var s = trimmed.components(separatedBy: invalid).joined(separator: "-")
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        if s.isEmpty { return "Presentation" }
        return String(s.prefix(80))
    }

    func importPreset(from data: Data) throws {
        let p = try decoder.decode(Preset.self, from: data)
        upsert(p)
    }
}
