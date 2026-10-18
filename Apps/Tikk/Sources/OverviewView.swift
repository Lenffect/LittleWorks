import SwiftUI
import LittleWorksCore

struct OverviewView: View {
    let model: AppModel
    let onEdit: (UUID) -> Void
    @State private var days: [DayGroup] = []
    @State private var projectRows: [ProjectStatus] = []
    @AppStorage(SettingsKey.animations) private var animations = true
    @AppStorage(SettingsKey.projectsEnabled) private var projectsEnabled = false

    /// Changes every minute and whenever the timer or clients change, to refresh the list.
    private var refreshKey: String {
        "\(Int(model.now.timeIntervalSince1970 / 60))-\(model.active?.id.uuidString ?? "-")-\(model.clients.count)-\(model.dataVersion)"
    }

    var body: some View {
        VStack(spacing: 0) {
            UrencriteriumBar(yearSeconds: model.yearTotal).padding([.horizontal, .top], 16)
            content
            if projectsEnabled && !projectRows.isEmpty {
                ProjectStatusBlock(rows: projectRows).padding(16)
            }
        }
        .task(id: refreshKey) {
            days = model.overviewDays()
            projectRows = model.projectStatuses()
        }
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
                                .modifier(HoverRow(animated: animations))
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

/// Highlights a clickable row on hover and shows the pointing hand, like the rows in the menu.
private struct HoverRow: ViewModifier {
    let animated: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
            .contentShape(Rectangle())
            .onHover { inside in
                hovering = inside
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .animation(animated ? .easeOut(duration: 0.12) : nil, value: hovering)
            .onDisappear { if hovering { NSCursor.pop(); hovering = false } }
    }
}
