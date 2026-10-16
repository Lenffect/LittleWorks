import SwiftUI

/// The real window: everything except quick start/stop.
struct MainWindowView: View {
    let model: AppModel

    enum Page: String, CaseIterable, Identifiable {
        case overview = "Overzicht", report = "Rapport", clients = "Klanten", settings = "Instellingen"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview: "list.bullet.rectangle"
            case .report: "chart.bar.doc.horizontal"
            case .clients: "person.2"
            case .settings: "gearshape"
            }
        }
    }

    struct EditTarget: Identifiable { let id: UUID }

    @State private var page: Page? = .overview
    @State private var editing: EditTarget?

    var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: $page) { p in
                Label(p.rawValue, systemImage: p.icon).tag(p)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch page ?? .overview {
            case .overview: OverviewView(model: model) { editing = EditTarget(id: $0) }
            case .report: ReportView(model: model)
            case .clients: ClientsView(model: model)
            case .settings: SettingsView(model: model)
            }
        }
        .navigationTitle(page?.rawValue ?? "tikk.")
        .frame(minWidth: 760, minHeight: 480)
        .sheet(item: $editing) { target in
            if let entry = model.entry(id: target.id) {
                EntryEditor(model: model, entry: entry) { editing = nil }
            }
        }
    }
}
