import SwiftUI
import LittleWorksCore

struct MenuView: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var newClient = ""

    var body: some View {
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
            Button("Overzicht openen") { openInFront("overview", title: WindowTitle.overview, using: openWindow) }
            Button("Instellingen…") { openInFront("settings", title: WindowTitle.settings, using: openWindow) }
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
