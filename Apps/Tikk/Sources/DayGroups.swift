import Foundation

struct DayRow: Identifiable {
    let id = UUID()
    let entryId: UUID
    let clientName: String
    var projectName: String? = nil
    let note: String?
    let start: Date
    let end: Date
    let isRunning: Bool
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

struct DayGroup: Identifiable {
    let day: Date
    var rows: [DayRow]
    var id: Date { day }
    var total: TimeInterval { rows.reduce(0) { $0 + $1.duration } }
}
