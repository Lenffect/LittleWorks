import SwiftUI
import LittleWorksCore

struct ReportView: View {
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
        "\(Int(Date().timeIntervalSince1970 / 60))-\(preset)-\(customStart)-\(customEnd)-\(selectedClients.map(\.uuidString).sorted())-\(model.dataVersion)"
    }

    private var totalSeconds: TimeInterval { rows.reduce(0) { $0 + $1.seconds } }
    private var totalIncome: Decimal { rows.compactMap(\.income).reduce(0, +) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Periode", selection: $preset) {
                    ForEach(Preset.allCases) { Text($0.title).tag($0) }
                }
                clientMenu
            }
            if preset == .custom {
                HStack {
                    DatePicker("Van", selection: $customStart, displayedComponents: .date)
                    DatePicker("tot en met", selection: $customEnd, displayedComponents: .date)
                }
            }
            Text(periodLabel).font(.caption).foregroundStyle(.secondary)
            Toggle("Verwachte inkomsten tonen (uurloon)", isOn: $showIncome)

            List {
                if rows.isEmpty {
                    Text("Geen uren in deze periode.").foregroundStyle(.secondary)
                }
                ForEach(rows) { row in
                    HStack {
                        Text(row.client.name)
                        Spacer()
                        if showIncome {
                            RateField(client: row.client) { model.setRate($0, for: row.client.id) }
                        }
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(Format.short(row.seconds)).monospacedDigit()
                            Text(tr("%@ u", row.hours.formatted(.number.precision(.fractionLength(2)).locale(L10n.language.locale))))
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .frame(width: 70, alignment: .trailing)
                        if showIncome {
                            Text(row.income.map { $0.formatted(.currency(code: "EUR").locale(L10n.language.locale)) } ?? "–")
                                .monospacedDigit().frame(width: 90, alignment: .trailing)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Text("Totaal").font(.headline)
                Spacer()
                Text(Format.short(totalSeconds)).monospacedDigit().font(.headline)
                if showIncome {
                    Text(totalIncome.formatted(.currency(code: "EUR").locale(L10n.language.locale)))
                        .monospacedDigit().font(.headline).frame(width: 90, alignment: .trailing)
                }
            }
            HStack {
                if showIncome {
                    Text("Indicatie: uren × uurloon, zonder btw of kosten.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Exporteer naar Excel…") {
                    model.exportReport(interval: interval, clientIds: selectedClients, includeIncome: showIncome)
                }
                .disabled(rows.isEmpty)
            }
            if let m = model.statusMessage { Text(m).font(.caption).foregroundStyle(.secondary) }
        }
        .padding([.horizontal, .bottom], 14)
        .padding(.top, 16)
        .task(id: refreshKey) { rows = model.report(in: interval, clientIds: selectedClients) }
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
            switch selectedClients.count {
            case 0: Text("Alle klanten")
            case 1: Text(model.allClients.first { selectedClients.contains($0.id) }?.name ?? tr("1 klant"))
            default: Text("\(selectedClients.count) klanten")
            }
        }
    }

    private var periodLabel: String {
        let i = interval
        let last = i.end.addingTimeInterval(-1)
        let f = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.language.locale)
        return "\(i.start.formatted(f)) – \(last.formatted(f))"
    }
}
