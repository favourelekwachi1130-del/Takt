import AppIntents
import Foundation

// MARK: - Entities

struct TaktPresetEntity: AppEntity {
    typealias DefaultQuery = TaktPresetQuery

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Talk preset")
    }

    static var defaultQuery = TaktPresetQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct TaktPresetQuery: EntityQuery {
    func entities(for identifiers: [TaktPresetEntity.ID]) async throws -> [TaktPresetEntity] {
        let all = TaktSharedPresetIndex.load()
        return all
            .filter { identifiers.contains($0.id) }
            .map { TaktPresetEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [TaktPresetEntity] {
        TaktSharedPresetIndex.load().map { TaktPresetEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - Intents

struct OpenTaktAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Takt"
    static var description = IntentDescription("Opens the Takt presentation timer.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct StartTaktTalkIntent: AppIntent {
    static var title: LocalizedStringResource = "Start talk with preset"
    static var description = IntentDescription("Opens Takt and starts the selected saved talk.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Preset")
    var preset: TaktPresetEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        TaktPendingShortcut.setPendingPreset(id: preset.id)
        return .result()
    }
}

// MARK: - Shortcuts list

struct TaktAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenTaktAppIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Open Takt",
            systemImageName: "timer"
        )
    }
}
