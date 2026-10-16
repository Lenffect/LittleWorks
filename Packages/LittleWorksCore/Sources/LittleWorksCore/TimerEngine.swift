import Foundation

public enum TimerError: Error, Equatable {
    case endBeforeStart
    case multipleActiveEntries
}

/// Starts, stops and switches timers. At most one entry is active at any time.
public final class TimerEngine {
    private let store: EntryStore
    private let time: TimeSource

    public init(store: EntryStore, time: TimeSource = SystemTimeSource()) {
        self.store = store
        self.time = time
    }

    public func activeEntry() throws -> TimeEntry? {
        try store.activeEntry()
    }

    /// Starts a timer for `clientId`. Any running timer is stopped at the same
    /// instant, so switching never leaves a gap or an overlap.
    /// Starting the client (and project) that is already running does nothing;
    /// a different project of the same client switches.
    @discardableResult
    public func start(clientId: UUID, projectId: UUID? = nil, note: String? = nil) throws -> TimeEntry {
        let now = time.now()
        if let running = try store.activeEntry() {
            if running.clientId == clientId && running.projectId == projectId { return running }
            try close(running, at: now)
        }
        let entry = TimeEntry(clientId: clientId, projectId: projectId, startTime: now, note: note)
        try store.save(entry)
        return entry
    }

    /// Stops the running timer. `date` lets the app cut off at an earlier moment
    /// (after sleep or a crash); it is clamped between the start and now.
    @discardableResult
    public func stop(at date: Date? = nil) throws -> TimeEntry? {
        guard let running = try store.activeEntry() else { return nil }
        let now = time.now()
        let requested = date ?? now
        let end = min(max(requested, running.startTime), now)
        return try close(running, at: end)
    }

    /// One click on a client: stop it if running, otherwise start it (switching if needed).
    public func toggle(clientId: UUID) throws {
        if let running = try store.activeEntry(), running.clientId == clientId {
            try stop()
        } else {
            try start(clientId: clientId)
        }
    }

    /// Validates and saves a manual edit.
    public func update(_ entry: TimeEntry) throws {
        if let end = entry.endTime, end < entry.startTime {
            throw TimerError.endBeforeStart
        }
        var saved = entry
        saved.updatedAt = time.now()
        try store.save(saved)
    }

    @discardableResult
    private func close(_ entry: TimeEntry, at end: Date) throws -> TimeEntry {
        var closed = entry
        closed.endTime = end
        closed.updatedAt = end
        try store.save(closed)
        return closed
    }
}
