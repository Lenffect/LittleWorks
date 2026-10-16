import SwiftUI
import LittleWorksCore

/// Compact menu: quick start/stop per client. Everything else lives in the main window.
struct MenuView: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.showMenuSummary) private var showSummary = true
    @AppStorage(SettingsKey.onboardingDone) private var onboardingDone = false
    @AppStorage(SettingsKey.animations) private var animations = true
    @FocusState private var newClientFocused: Bool
    @State private var newClient = ""

    /// Fixed size, also for the note prompt, so the popover never resizes or jumps.
    static let size = CGSize(width: 300, height: 440)

    var body: some View {
        Group {
            if !onboardingDone {
                OnboardingView()
            } else if let id = model.notePromptEntryId, let entry = model.entry(id: id) {
                NotePrompt(model: model, entry: entry)
            } else {
                main
            }
        }
        .fontDesign(.rounded)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
        .background(Brand.background)
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.clients) { client in
                        ClientRow(
                            client: client,
                            isRunning: model.active?.clientId == client.id,
                            today: model.todayByClient[client.id] ?? 0,
                            animated: animations
                        ) { model.toggle(client) }
                        .contextMenu { Button("Archiveren") { model.archive(client) } }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                TextField("Nieuwe klant", text: $newClient)
                    .textFieldStyle(.roundedBorder)
                    .focused($newClientFocused)
                    .onSubmit(add)
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

    /// Tikk's pose follows what is happening: working, just finished, no clients yet, or asleep.
    private var pose: TikkPose {
        if model.active != nil { return .master }
        if justStopped { return .klaar }
        return model.clients.isEmpty ? .leeg : .slaap
    }

    private var justStopped: Bool {
        guard let t = model.lastStopped else { return false }
        return model.now.timeIntervalSince(t) < 4
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: 12) {
            TikkFigure(pose: pose, scale: 3)
            if let c = model.activeClient {
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(.headline).lineLimit(1)
                    Text(Format.duration(model.activeElapsed)).monospacedDigit().font(.title2.weight(.semibold))
                }
                Spacer()
                Button { model.stop() } label: {
                    Text("Stop").font(.title3.weight(.semibold)).frame(width: 56).frame(minHeight: 28)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.escape, modifiers: [])
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Wordmark(scale: 1.5)
                    Text(idleText).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .frame(height: 60)
    }

    private var idleText: String {
        if justStopped { return "Klaar! Mooi werk." }
        return model.clients.isEmpty ? "Voeg je eerste klant toe." : "Geen timer actief."
    }

    private func row(_ title: String, _ seconds: TimeInterval) -> some View {
        HStack { Text(title); Spacer(); Text(Format.short(seconds)).monospacedDigit() }
    }

    private func add() {
        if model.addClient(name: newClient) { newClient = "" }
    }
}

/// One client row: the whole row is clickable, and highlights on hover to show that.
private struct ClientRow: View {
    let client: Client
    let isRunning: Bool
    let today: TimeInterval
    let animated: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isRunning ? "stop.circle.fill" : "play.circle").font(.title2)
                Text(client.name).font(.title3).lineLimit(1)
                Spacer()
                Text(Format.short(today)).monospacedDigit().foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(hovering ? 0.10 : (isRunning ? 0.06 : 0)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(animated ? .easeOut(duration: 0.12) : nil, value: hovering)
    }
}
