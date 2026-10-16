import SwiftUI
import LittleWorksCore

struct MenuView: View {
    let model: AppModel
    @State private var newClient = ""
    @State private var screen: Screen = .main

    enum Screen: Equatable { case main, overview, settings, edit(UUID) }

    var body: some View {
        switch screen {
        case .main: main
        case .overview:
            page("Overzicht") {
                OverviewView(model: model) { screen = .edit($0) }
            }
            .frame(width: 560, height: 480)
        case .settings:
            page("Instellingen") { SettingsView() }
        case .edit(let id):
            if let entry = model.entry(id: id) {
                EntryEditor(model: model, entry: entry) { screen = .overview }
            } else {
                page("Overzicht") { Text("Registratie bestaat niet meer.") }
                    .onAppear { screen = .overview }
            }
        }
    }

    private func page<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { screen = .main } label: { Label("Terug", systemImage: "chevron.left") }
                Spacer()
                Text(title).font(.headline)
                Spacer()
                Color.clear.frame(width: 60, height: 1)
            }
            .padding([.horizontal, .top], 14)
            content()
        }
    }

    private var main: some View {
        HStack(alignment: .top, spacing: 14) {
            controls.frame(width: 190)
            Divider()
            clientList.frame(width: 240)
        }
        .padding(14)
    }

    // MARK: - Links: controle en opties

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let c = model.activeClient {
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(.headline)
                    Text(Format.duration(model.activeElapsed)).monospacedDigit().font(.title2)
                }
                Button { model.stop() } label: {
                    Text("Stop").font(.title3.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 32)
                }
                .controlSize(.large)
                .keyboardShortcut(.escape, modifiers: [])
            } else {
                Text("Geen timer actief").foregroundStyle(.secondary)
            }

            Divider()
            row("Vandaag", model.todayTotal)
            row("Deze week", model.weekTotal)
            UrencriteriumBar(yearSeconds: model.yearTotal)
            Divider()

            TextField("Nieuwe klant", text: $newClient)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
            Button("Voeg toe", action: add)
                .disabled(newClient.trimmingCharacters(in: .whitespaces).isEmpty)

            Divider()
            Button("Overzicht openen") { screen = .overview }
            Button("Instellingen…") { screen = .settings }
            Button("Back-up maken…") { model.exportBackup() }
            Toggle("Start bij inloggen", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
            if let m = model.statusMessage { Text(m).foregroundStyle(.secondary).font(.caption) }
            if let e = model.errorMessage { Text(e).foregroundStyle(.red).font(.caption) }
            Spacer(minLength: 0)
            Button("Stop tikk.") { NSApp.terminate(nil) }
        }
    }

    // MARK: - Rechts: klantnamen

    private var clientList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.clients.isEmpty {
                Text("Nog geen klanten.\nVoeg er links één toe.").foregroundStyle(.secondary)
            }
            ForEach(model.clients) { client in
                Button { model.toggle(client) } label: {
                    HStack {
                        Image(systemName: model.active?.clientId == client.id ? "stop.circle.fill" : "play.circle")
                            .font(.title2)
                        Text(client.name).font(.title3).lineLimit(1)
                        Spacer()
                        Text(Format.short(model.todayByClient[client.id] ?? 0))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { Button("Archiveren") { model.archive(client) } }
            }
            Spacer(minLength: 0)
        }
    }

    private func row(_ title: String, _ seconds: TimeInterval) -> some View {
        HStack { Text(title); Spacer(); Text(Format.short(seconds)).monospacedDigit() }
    }

    private func add() {
        model.addClient(name: newClient)
        newClient = ""
    }
}
