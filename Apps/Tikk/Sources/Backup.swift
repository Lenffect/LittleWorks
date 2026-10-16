import AppKit
import Foundation
import SwiftData
import LittleWorksCore

struct BackupFile: Codable {
    var version = 1
    var exportedAt: Date
    var clients: [Client]
    var entries: [TimeEntry]
}

enum Backup {
    /// Writes all clients (incl. archived) and entries to a JSON file the user picks.
    @MainActor
    static func export(from context: ModelContext) throws -> URL? {
        let clients = try context.fetch(FetchDescriptor<ClientRecord>(sortBy: [SortDescriptor(\.createdAt)])).map(\.value)
        let entries = try context.fetch(FetchDescriptor<EntryRecord>(sortBy: [SortDescriptor(\.startTime)])).map(\.value)

        let panel = NSSavePanel()
        let day = Date.now.formatted(.iso8601.year().month().day())
        panel.nameFieldStringValue = "tikk-backup-\(day).json"
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(BackupFile(exportedAt: Date(), clients: clients, entries: entries))
        try data.write(to: url, options: .atomic)
        return url
    }
}
