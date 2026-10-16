import SwiftUI
import LittleWorksCore

/// Compact menu: quick start/stop per client. Everything else lives in the main window.
struct MenuView: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.showMenuSummary) private var showSummary = true
    @State private var newClient = ""

    /// Fixed size, also for the note prompt, so the popover never resizes or jumps.
    static let size = CGSize(width: 300, height: 440)

    var body: some View {
        Group {
            if let id = model.notePromptEntryId, let entry = model.entry(id: id) {
                NotePrompt(model: model, entry: entry)
            } else {
                main
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 10) {
            timer
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if model.clients.isEmpty {
                        Text("Nog geen klanten.\nVoeg er hieronder één toe.").foregroundStyle(.secondary)
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                TextField("Nieuwe klant", text: $newClient).textFieldStyle(.roundedBorder).onSubmit(add)
                .onChange(of: newClient) { model.errorMessage = nil }
                Button("Voeg toe", action: add)
                    .disabled(newClient.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if showSummary {
                Divider()
                row("Vandaag", model.todayTotal)
                row("Deze week", model.weekTotal)
                UrencriteriumBar(yearSeconds: model.yearTotal)
            }

            if let e = model.errorMessage { Text(e).foregroundStyle(.red).font(.caption) }
            Divider()
            HStack {
                Button("Open tikk.") { openMainWindow(model: model, using: openWindow) }
                Spacer()
                Button("Stop tikk.") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
    }

    @ViewBuilder private var timer: some View {
        if let c = model.activeClient {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(.headline)
                    Text(Format.duration(model.activeElapsed)).monospacedDigit().font(.title2)
                }
                Spacer()
                Button { model.stop() } label: {
                    Text("Stop").font(.title3.weight(.semibold)).frame(width: 70).frame(minHeight: 32)
                }
                .controlSize(.large)
                .keyboardShortcut(.escape, modifiers: [])
            }
        } else {
            Text("Geen timer actief").foregroundStyle(.secondary).frame(minHeight: 32)
        }
    }

    private func row(_ title: String, _ seconds: TimeInterval) -> some View {
        HStack { Text(title); Spacer(); Text(Format.short(seconds)).monospacedDigit() }
    }

    private func add() {
        if model.addClient(name: newClient) { newClient = "" }
    }
}
