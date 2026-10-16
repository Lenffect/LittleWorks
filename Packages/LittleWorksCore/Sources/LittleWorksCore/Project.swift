import Foundation

public enum ProjectKind: String, Codable, Sendable, CaseIterable {
    /// Billed per hour; `price` is the hourly rate, or nil to use the client's rate.
    case hourly
    /// Fixed price for the whole project; `price` is the total.
    case fixed
}

/// An optional layer between client and time entry.
public struct Project: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var clientId: UUID
    public var name: String
    public var kind: ProjectKind
    public var price: Decimal?
    public var estimatedHours: Double?
    public var isArchived: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        clientId: UUID,
        name: String,
        kind: ProjectKind = .hourly,
        price: Decimal? = nil,
        estimatedHours: Double? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.clientId = clientId
        self.name = name
        self.kind = kind
        self.price = price
        self.estimatedHours = estimatedHours
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

public struct ProjectStats: Equatable, Sendable {
    public let seconds: TimeInterval
    public var hours: Double { seconds / 3600 }
    /// Hours worked divided by the estimate; above 1 means over budget. Nil without a usable estimate.
    public let progress: Double?
    /// Estimate minus hours worked; negative when over budget.
    public let hoursRemaining: Double?
    /// Fixed: price (what the project brings in). Hourly: rate × hours.
    public let revenue: Decimal?
    /// Fixed: price ÷ hours worked. Hourly: the rate itself. Nil when it cannot be determined.
    public let effectiveRate: Decimal?
}

public enum ProjectMath {
    public static func stats(for project: Project, clientRate: Decimal?, seconds: TimeInterval) -> ProjectStats {
        let hours = seconds / 3600
        let estimate = project.estimatedHours.flatMap { $0 > 0 ? $0 : nil }

        let revenue: Decimal?
        let effective: Decimal?
        switch project.kind {
        case .fixed:
            revenue = project.price
            effective = project.price.flatMap { hours > 0 ? $0 / Decimal(hours) : nil }
        case .hourly:
            let rate = project.price ?? clientRate
            revenue = rate.map { $0 * Decimal(hours) }
            effective = rate
        }

        return ProjectStats(
            seconds: seconds,
            progress: estimate.map { hours / $0 },
            hoursRemaining: estimate.map { $0 - hours },
            revenue: revenue,
            effectiveRate: effective)
    }
}

public extension ProjectMath {
    /// Budget warning level for a progress fraction: 100 once the estimate is reached,
    /// 80 from 80% on, nil below that.
    static func alertLevel(progress: Double) -> Int? {
        if progress >= 1 { return 100 }
        if progress >= 0.8 { return 80 }
        return nil
    }

    /// Expected income for one client over a period: time not on a project and time on hourly
    /// projects, each at its own rate. Fixed-price projects are left out (their price is not tied to a period).
    /// Nil when no applicable rate is known.
    static func expectedIncome(
        clientRate: Decimal?,
        clientSeconds: TimeInterval,
        projects: [(project: Project, seconds: TimeInterval)]
    ) -> Decimal? {
        var parts: [Decimal] = []
        let onProjects = projects.reduce(0) { $0 + $1.seconds }
        if let clientRate {
            parts.append(clientRate * Decimal(max(0, clientSeconds - onProjects)) / 3600)
        }
        for (project, seconds) in projects where project.kind == .hourly {
            if let rate = project.price ?? clientRate { parts.append(rate * Decimal(seconds) / 3600) }
        }
        return parts.isEmpty ? nil : parts.reduce(0, +)
    }
}

public extension Totals {
    /// Exact seconds per project inside `interval`; entries without a project are left out.
    static func secondsPerProject(
        entries: [TimeEntry],
        in interval: DateInterval,
        now: Date
    ) -> [UUID: TimeInterval] {
        var totals: [UUID: TimeInterval] = [:]
        for entry in entries {
            guard let projectId = entry.projectId else { continue }
            let start = max(entry.startTime, interval.start)
            let end = min(entry.endTime ?? now, interval.end)
            if end > start { totals[projectId, default: 0] += end.timeIntervalSince(start) }
        }
        return totals
    }
}
