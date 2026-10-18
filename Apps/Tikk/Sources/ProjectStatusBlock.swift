import SwiftUI
import LittleWorksCore

func money(_ d: Decimal) -> String {
    d.formatted(.number.precision(.fractionLength(2)).locale(L10n.language.locale))
}

/// Where every active project stands: hours against the estimate, and what it earns per hour.
struct ProjectStatusBlock: View {
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
