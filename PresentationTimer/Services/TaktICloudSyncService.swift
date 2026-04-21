import CloudKit
import Foundation

/// Syncs the presets JSON blob through the user's **private** CloudKit database (Apple ID, no Takt account).
enum TaktICloudPresetsSync {
    private static let containerIdentifier = "iCloud.com.presentationtimer.PresentationTimer"
    private static let recordType = "PresetLibrary"
    private static let recordName = "singleton"
    private static let payloadField = "payload"

    private static var database: CKDatabase {
        CKContainer(identifier: containerIdentifier).privateCloudDatabase
    }

    static func accountStatus() async -> CKAccountStatus {
        let container = CKContainer(identifier: containerIdentifier)
        do {
            return try await container.accountStatus()
        } catch {
            return .couldNotDetermine
        }
    }

    static func isAvailableForSync() async -> Bool {
        await accountStatus() == .available
    }

    /// Short string for Settings (e.g. “On”, “Not signed in”).
    static func iCloudStatusLabel() async -> String {
        switch await accountStatus() {
        case .available:
            return "On"
        case .noAccount:
            return "Not signed in"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Unavailable"
        case .temporarilyUnavailable:
            return "Temporarily unavailable"
        @unknown default:
            return "Unknown"
        }
    }

    /// Fetches remote presets payload, or `nil` if nothing is in iCloud yet.
    static func fetchPresetsPayload() async throws -> (data: Data, modified: Date)? {
        let id = CKRecord.ID(recordName: recordName)
        do {
            let record = try await database.record(for: id)
            let raw = record[payloadField]
            let data: Data? = {
                if let d = raw as? Data { return d }
                if let n = raw as? NSData { return n as Data }
                return nil
            }()
            guard let data else { return nil }
            let mod = record.modificationDate ?? record.creationDate ?? .distantPast
            return (data, mod)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    /// Writes or overwrites the presets blob in the private database.
    static func savePresetsPayload(_ data: Data) async throws {
        let id = CKRecord.ID(recordName: recordName)
        let record: CKRecord
        do {
            record = try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: id)
        }
        record[payloadField] = data as NSData
        _ = try await database.save(record)
    }
}
