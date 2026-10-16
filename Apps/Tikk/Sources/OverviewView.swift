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

/// Where every active project stands: hours against the estimate, and what it earns per hour.
private struct ProjectStatusBlock: View {
    let rows: [ProjectStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projecten").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(rows) { row in line(row) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 170)
            .fixedSize(horizontal: false, vertical: rows.count <= 3)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }

    private func line(_ row: ProjectStatus) -> some View {
        let s = row.stats
        let over = (s.progress ?? 0) > 1
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("\(row.clientName) · \(row.project.name)").lineLimit(1)
                Spacer()
                Text(hoursText(row)).monospacedDigit()
                    .foregroundStyle(over ? Color.red : Color.secondary)
            }
            if let progress = s.progress {
                ProgressView(value: min(1, progress)).tint(over ? .red : (progress >= 0.8 ? .orange : .accentColor))
            }
            if let detail = detailText(row) {
                Text(detail).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }

    private func hoursText(_ row: ProjectStatus) -> String {
        guard let est = row.project.estimatedHours, est > 0 else { return tr("%@ u", Format.short(row.stats.seconds)) }
        return tr("%@ van %@ u", Format.short(row.stats.seconds), est.formatted(.number.locale(L10n.language.locale)))
    }

    private func detailText(_ row: ProjectStatus) -> String? {
        var parts: [String] = []
        switch row.project.kind {
        case .fixed:
            if let price = row.project.price { parts.append(tr("vast €%@", money(price))) }
            if let rate = row.stats.effectiveRate { parts.append(tr("effectief €%@/u", money(rate))) }
        case .hourly:
            if let revenue = row.stats.revenue, revenue > 0 { parts.append(tr("omzet €%@", money(revenue))) }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
