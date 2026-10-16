import Foundation

public struct Client: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var hourlyRate: Decimal?
    /// Fixed fee per month; used to show the effective hourly rate.
    public var monthlyFee: Decimal?
    public var isArchived: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#FF8A4C",
        hourlyRate: Decimal? = nil,
        monthlyFee: Decimal? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.hourlyRate = hourlyRate
        self.monthlyFee = monthlyFee
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

public struct TimeEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var clientId: UUID
    /// Reserved for brix; tikk itself only tracks per client.
    public var projectId: UUID?
    public var startTime: Date
    /// `nil` means the entry is still running.
    public var endTime: Date?
    public var note: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        clientId: UUID,
        projectId: UUID? = nil,
        startTime: Date,
        endTime: Date? = nil,
        note: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.projectId = projectId
        self.startTime = startTime
        self.endTime = endTime
        self.note = note
        self.createdAt = createdAt ?? startTime
        self.updatedAt = updatedAt ?? startTime
    }

    public var isActive: Bool { endTime == nil }

    /// Exact duration; for a running entry, measured up to `now`.
    public func duration(at now: Date) -> TimeInterval {
        max(0, (endTime ?? now).timeIntervalSince(startTime))
    }
}
