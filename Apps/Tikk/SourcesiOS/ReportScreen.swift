import SwiftUI
import LittleWorksCore

struct ReportScreen: View {
    let model: AppModel

    enum Preset: String, CaseIterable, Identifiable {
        case thisWeek = "Deze week", lastWeek = "Vorige week"
        case thisMonth = "Deze maand", lastMonth = "Vorige maand"
        case thisYear = "Dit jaar", custom = "Aangepast"
        var id: String { rawValue }
        var title: LocalizedStringKey { LocalizedStringKey(rawValue) }
    }

    @State private var preset: Preset = .thisMonth
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    @State private var customEnd = Date()
    @State private var selectedClients: Set<UUID> = []
    @State private var rows: [ReportRow] = []
    @State private var exportURL: URL?
    @AppStorage(SettingsKey.reportShowIncome) private var showIncome = false

    private var interval: DateInterval {
        let cal = Calendar.current
        let now = Date()
        func range(_ c: Calendar.Component, offset: Int = 0) -> DateInterval {
            let anchor = cal.date(byAdding: c, value: offset, to: now)!
            return cal.dateInterval(of: c, for: anchor) ?? DateInterval(start: now, duration: 1)
        }
        switch preset {
        case .thisWeek: return range(.weekOfYear)
        case .lastWeek: return range(.weekOfYear, offset: -1)
        case .thisMonth: return range(.month)
        case .lastMonth: return range(.month, offset: -1)
        case .thisYear: return range(.year)
        case .custom:
            let start = cal.startOfDay(for: min(customStart, customEnd))
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: max(customStart, customEnd)))!
            return DateInterval(start: start, end: end)
        }
    }

    private var refreshKey: String {
        "\(Int(Date().timeIntervalSince1970 / 60))-\(preset)-\(customStart)-\(customEnd)-\(selectedClients.map(\.uuidString).sorted())-\(showIncome)-\(model.dataVersion)"
    }

    private var totalSeconds: TimeInterval { rows.reduce(0) { $0 + $1.seconds } }
    private var totalIncome: Decimal { rows.compactMap(\.income).reduce(0, +) }
    private func euro(_ d: Decimal) -> String { d.formatted(.currency(code: "EUR").locale(L10n.language.locale)) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Periode", selection: $preset) {
                        ForEach(Preset.allCases) { Text($0.title).tag($0) }
                    }
                    if preset == .custom {
                        DatePicker("Van", selection: $customStart, displayedComponents: .date)
                        DatePicker("tot en met", selection: $customEnd, displayedComponents: .date)
                    }
                    clientMenu
                    Toggle("Verwachte inkomsten tonen (uurloon)", isOn: $showIncome)
                } footer: { Text(periodLabel) }

                Section {
                    if rows.isEmpty { Text("Geen uren in deze periode.").foregroundStyle(.secondary) }
                    ForEach(rows) { row in rowView(row) }
                }

                if !rows.isEmpty {
                    Section {
                        HStack {
                            Text("Totaal").font(.headline)
                            Spacer()
                            Text(Format.short(totalSeconds)).monospacedDigit().font(.headline)
                            if showIncome { Text(euro(totalIncome)).monospacedDigit().font(.headline) }
                        }
                        if let exportURL { ShareLink("Exporteer naar Excel…", item: exportURL) }
                    } footer: {
                        if showIncome { Text("Indicatie: uren × uurloon, zonder btw of kosten.") }
                    }
                }
            }
            .navigationTitle("Rapport")
            .task(id: refreshKey) {
                rows = model.report(in: interval, clientIds: selectedClients)
                exportURL = rows.isEmpty ? nil : try? ReportExport.writeTemporary(
                    entries: model.exportEntries(in: interval, clientIds: selectedClients),
                    summary: rows, interval: interval, includeIncome: showIncome)
            }
        }
    }

    private var clientMenu: some View {
        Menu {
            Button("Alle klanten") { selectedClients = [] }
            Divider()
            ForEach(model.allClients) { client in
                Toggle(client.name, isOn: Binding(
                    get: { selectedClients.contains(client.id) },
                    set: { on in if on { selectedClients.insert(client.id) } else { selectedClients.remove(client.id) } }))
            }
        } label: {
            HStack {
                Text("Klanten").foregroundStyle(Brand.ink)
                Spacer()
                switch selectedClients.count {
                case 0: Text("Alle klanten")
                case 1: Text(model.allClients.first { selectedClients.contains($0.id) }?.name ?? tr("1 klant"))
                default: Text("\(selectedClients.count) klanten")
                }
            }
        }
    }

    private func rowView(_ row: ReportRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.client.name)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Format.short(row.seconds)).monospacedDigit()
                    Text(tr("%@ u", row.hours.formatted(.number.precision(.fractionLength(2)).locale(L10n.language.locale))))
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            if showIncome {
                HStack {
                    Text(row.effectiveRate.map { tr("%@/u effectief", euro($0)) } ?? "")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(row.income.map(euro) ?? "–").monospacedDigit().font(.callout)
                }
            }
            ForEach(row.projects) { line in projectRow(line) }
            if !row.projects.isEmpty, row.unassignedSeconds > 0 {
                subRow(Text("Algemeen werk"), seconds: row.unassignedSeconds, detail: "", income: nil, over: false)
            }
        }
        .padding(.vertical, 2)
    }

    private func projectRow(_ line: ProjectLine) -> some View {
        let stats = line.stats
        var parts: [String] = []
        if let progress = stats.progress, let est = line.project.estimatedHours {
            parts.append(tr("%lld%% van %@ u", Int(progress * 100), est.formatted(.number.locale(L10n.language.locale))))
        }
        if showIncome, line.project.kind == .fixed, let r = stats.effectiveRate {
            parts.append(tr("%@/u effectief", euro(r)))
            parts.append(tr("%@ u totaal", Format.short(line.totalSeconds)))
        }
        return subRow(Text(verbatim: line.project.name), seconds: line.seconds, detail: parts.joined(separator: " · "),
                      income: line.income, over: (stats.progress ?? 0) > 1)
    }

    private func subRow(_ name: Text, seconds: TimeInterval, detail: String, income: Decimal?, over: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text("↳").foregroundStyle(.secondary)
                name
                Spacer()
                Text(Format.short(seconds)).monospacedDigit().foregroundStyle(.secondary)
                if showIncome, let income { Text(euro(income)).monospacedDigit().foregroundStyle(.secondary) }
            }
            if !detail.isEmpty {
                Text(detail).font(.caption).foregroundStyle(over ? Color.red : Color.secondary).padding(.leading, 18)
            }
        }
        .font(.callout)
    }

    private var periodLabel: String {
        let i = interval
        let last = i.end.addingTimeInterval(-1)
        let f = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.language.locale)
        return "\(i.start.formatted(f)) – \(last.formatted(f))"
    }
}
