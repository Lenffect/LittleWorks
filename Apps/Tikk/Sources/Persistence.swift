import Foundation
import SwiftData
import LittleWorksCore

@Model
final class ClientRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var hourlyRate: Decimal?
    var isArchived: Bool
    var createdAt: Date

    init(_ c: Client) {
        id = c.id; name = c.name; colorHex = c.colorHex
        hourlyRate = c.hourlyRate; isArchived = c.isArchived; createdAt = c.createdAt
    }

    var value: Client {
        Client(id: id, name: name, colorHex: colorHex, hourlyRate: hourlyRate,
               isArchived: isArchived, createdAt: createdAt)
    }
}

@Model
final class EntryRecord {
    @Attribute(.unique) var id: UUID
    var clientId: UUID
    var projectId: UUID?
    var startTime: Date
    var endTime: Date?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(_ e: TimeEntry) {
        id = e.id; clientId = e.clientId; projectId = e.projectId
        startTime = e.startTime; endTime = e.endTime; note = e.note
        createdAt = e.createdAt; updatedAt = e.updatedAt
    }

    func apply(_ e: TimeEntry) {
        clientId = e.clientId; projectId = e.projectId
        startTime = e.startTime; endTime = e.endTime; note = e.note
        updatedAt = e.updatedAt
    }

    var value: TimeEntry {
        TimeEntry(id: id, clientId: clientId, projectId: projectId, startTime: startTime,
                  endTime: endTime, note: note, createdAt: createdAt, updatedAt: updatedAt)
    }
}

/// SwiftData-backed store. Only use from the main actor (the context is the main context).
final class SwiftDataEntryStore: EntryStore {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    private func record(id: UUID) throws -> EntryRecord? {
        var d = FetchDescriptor<EntryRecord>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func activeEntry() throws -> TimeEntry? {
        var d = FetchDescriptor<EntryRecord>(predicate: #Predicate { $0.endTime == nil })
        d.fetchLimit = 1
        return try context.fetch(d).first?.value
    }

    func entries(in interval: DateInterval) throws -> [TimeEntry] {
        let start = interval.start, end = interval.end
        let d = FetchDescriptor<EntryRecord>(
            predicate: #Predicate { $0.startTime < end && ($0.endTime == nil || $0.endTime! > start) },
            sortBy: [SortDescriptor(\.startTime)])
        return try context.fetch(d).map(\.value)
    }

    func save(_ entry: TimeEntry) throws {
        if let r = try record(id: entry.id) { r.apply(entry) } else { context.insert(EntryRecord(entry)) }
        try context.save()
    }

    func deleteEntry(id: UUID) throws {
        if let r = try record(id: id) { context.delete(r); try context.save() }
    }
}
