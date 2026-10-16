import SwiftUI
import LittleWorksCore

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

struct OverviewView: View {
    let model: AppModel
    let onEdit: (UUID) -> Void
    @State private var days: [DayGroup] = []
    @AppStorage(SettingsKey.projectsEnabled) private var projectsEnabled = false

    /// Changes every minute and whenever the timer or clients change, to refresh the list.
    private var refreshKey: String {
        "\(Int(model.now.timeIntervalSince1970 / 60))-\(model.active?.id.uuidString ?? "-")-\(model.clients.count)-\(model.dataVersion)"
    }

    var body: some View {
        VStack(spacing: 0) {
            UrencriteriumBar(yearSeconds: model.yearTotal).padding([.horizontal, .top], 16)
            content
        }
        .task(id: refreshKey) { days = model.overviewDays() }
    }

    @ViewBuilder private var content: some View {
        Group {
            if days.isEmpty {
                VStack(spacing: 10) {
                    TikkFigure(pose: .leeg, scale: 4)
                    Text("Nog geen registraties.").font(.title3.weight(.semibold))
                    Text("Start een timer vanuit de menubalk, dan verschijnt hij hier.").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(days) { group in
                        Section {
                            ForEach(group.rows) { row in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(projectsEnabled && row.projectName != nil ? "\(row.clientName) · \(row.projectName!)" : row.clientName).font(.body)
                                        if let n = row.note { Text(n).font(.caption).foregroundStyle(.secondary) }
                                    }
                                    if row.isRunning { Text("● loopt").foregroundStyle(.orange).font(.caption) }
                                    Spacer()
                                    Text("\(row.start.formatted(date: .omitted, time: .shortened)) – \(row.isRunning ? tr("nu") : row.end.formatted(date: .omitted, time: .shortened))")
                                        .foregroundStyle(.secondary)
                                    Text(Format.short(row.duration)).monospacedDigit().frame(width: 56, alignment: .trailing)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { onEdit(row.entryId) }
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
    }
}
