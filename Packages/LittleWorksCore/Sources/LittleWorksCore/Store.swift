import Foundation

/// Source of "now". Injected so tests can control time.
public protocol TimeSource {
    func now() -> Date
}

public struct SystemTimeSource: TimeSource {
    public init() {}
    public func now() -> Date { Date() }
}

/// Persistence boundary. The app supplies a SwiftData-backed implementation;
/// the engine and tests only see this protocol.
public protocol EntryStore: AnyObject {
    func activeEntry() throws -> TimeEntry?
    func entries(in interval: DateInterval) throws -> [TimeEntry]
    func save(_ entry: TimeEntry) throws
    func deleteEntry(id: UUID) throws
}

/// Simple in-memory store, used by tests and previews.
public final class InMemoryEntryStore: EntryStore {
    private var storage: [UUID: TimeEntry] = [:]

    public init() {}

    public func activeEntry() throws -> TimeEntry? {
        storage.values.first { $0.isActive }
    }

    public func entries(in interval: DateInterval) throws -> [TimeEntry] {
        storage.values
            .filter { entry in
                let end = entry.endTime ?? .distantFuture
                return entry.startTime < interval.end && end > interval.start
            }
            .sorted { $0.startTime < $1.startTime }
    }

    public func save(_ entry: TimeEntry) throws {
        storage[entry.id] = entry
    }

    public func deleteEntry(id: UUID) throws {
        storage[id] = nil
    }
}
