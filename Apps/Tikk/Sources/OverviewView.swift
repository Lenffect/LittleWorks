import SwiftUI
import LittleWorksCore

struct DayRow: Identifiable {
    let id = UUID()
    let clientName: String
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

struct OverviewView: View {
    let model: AppModel
    @State private var days: [DayGroup] = []

    /// Changes every minute and whenever the timer or clients change, to refresh the list.
    private var refreshKey: String {
        "\(Int(model.now.timeIntervalSince1970 / 60))-\(model.active?.id.uuidString ?? "-")-\(model.clients.count)"
    }

    var body: some View {
        Group {
            if days.isEmpty {
                Text("Nog geen registraties.").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(days) { group in
                        Section {
                            ForEach(group.rows) { row in
                                HStack {
                                    Text(row.clientName).font(.body)
                                    if row.isRunning { Text("● loopt").foregroundStyle(.orange).font(.caption) }
                                    Spacer()
                                    Text("\(row.start.formatted(date: .omitted, time: .shortened)) – \(row.isRunning ? "nu" : row.end.formatted(date: .omitted, time: .shortened))")
                                        .foregroundStyle(.secondary)
                                    Text(Format.short(row.duration)).monospacedDigit().frame(width: 56, alignment: .trailing)
                                }
                            }
                        } header: {
                            HStack {
                                Text(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                                Spacer()
                                Text(Format.short(group.total)).monospacedDigit()
                            }
                            .font(.headline)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 360)
        .task(id: refreshKey) { days = model.overviewDays() }
    }
}
