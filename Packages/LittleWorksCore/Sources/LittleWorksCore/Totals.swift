import Foundation

/// The part of an entry that falls on one calendar day.
public struct DaySegment: Equatable, Sendable {
    public let day: Date          // start of the day in the given calendar
    public let start: Date
    public let end: Date
    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

public enum Totals {
    /// Splits an entry at local midnights. A running entry counts up to `now`.
    public static func segments(
        of entry: TimeEntry,
        now: Date,
        calendar: Calendar = .current
    ) -> [DaySegment] {
        let end = entry.endTime ?? now
        guard end > entry.startTime else { return [] }

        var result: [DaySegment] = []
        var cursor = entry.startTime
        while cursor < end {
            let dayStart = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let segmentEnd = min(end, nextDay)
            result.append(DaySegment(day: dayStart, start: cursor, end: segmentEnd))
            cursor = segmentEnd
        }
        return result
    }

    /// Exact seconds per client inside `interval`, clipping entries at the edges.
    public static func secondsPerClient(
        entries: [TimeEntry],
        in interval: DateInterval,
        now: Date
    ) -> [UUID: TimeInterval] {
        var totals: [UUID: TimeInterval] = [:]
        for entry in entries {
            let start = max(entry.startTime, interval.start)
            let end = min(entry.endTime ?? now, interval.end)
            if end > start {
                totals[entry.clientId, default: 0] += end.timeIntervalSince(start)
            }
        }
        return totals
    }
}
