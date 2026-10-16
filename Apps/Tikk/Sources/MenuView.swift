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
    @State private var expandedClient: UUID?
    @State private var dragging: UUID?
    @State private var dropTarget: UUID?
    @AppStorage(SettingsKey.projectsEnabled) private var projectsEnabled = false

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
                    let _ = model.dataVersion   // refresh when projects change
                    let projects = projectsEnabled ? model.allProjects.filter { !$0.isArchived } : []
                    ForEach(model.clients) { client in
                        let clientProjects = projects.filter { $0.clientId == client.id }
                        let running = model.active?.clientId == client.id
                        ClientRow(
                            client: client,
                            isRunning: running,
                            today: model.todayByClient[client.id] ?? 0,
                            animated: animations,
                            projects: clientProjects,
                            runningProjectId: running ? model.active?.projectId : nil,
                            expanded: expandedClient == client.id,
                            onToggleExpand: { expandedClient = expandedClient == client.id ? nil : client.id },
                            onPick: { project in
                                model.start(client, project: project)
                                expandedClient = nil
                            }
                        ) {
                            if running {
                                model.stop()
                            } else if clientProjects.isEmpty {
                                model.toggle(client)
                            } else {
                                expandedClient = expandedClient == client.id ? nil : client.id
                            }
                        }
                        .contextMenu { Button("Archiveren") { model.archive(client) } }
                        .overlay(alignment: dropAtBottom(of: client) ? .bottom : .top) {
                            if dropTarget == client.id, dragging != client.id {
                                Capsule().fill(Brand.green).frame(height: 3).padding(.horizontal, 8)
                                    .offset(y: dropAtBottom(of: client) ? 5.5 : -5.5)
                            }
                        }
                        .onDrag {
                            dragging = client.id
                            return NSItemProvider(object: client.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: ClientDrop(
                            target: client.id, model: model, dragging: $dragging, dropTarget: $dropTarget))
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

    /// Dragging downwards lands after the target row, upwards before it.
    private func dropAtBottom(of client: Client) -> Bool {
        guard let d = dragging, let from = model.clients.firstIndex(where: { $0.id == d }),
              let to = model.clients.firstIndex(where: { $0.id == client.id }) else { return false }
        return from < to
    }

    /// Tikk's pose follows what is happening: working, just finished, no clients yet, or asleep.
    private var pose: TikkPose {
        if model.active != nil { return .master }
        if justStopped { return .klaar }
        return model.clients.isEmpty ? .leeg : .slaap
    }

    private var justStopped: Bool {
        guard let t = model.lastStopped else { return false }
        return model.now.timeIntervalSince(t) < 5
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: 12) {
            TikkFigure(pose: pose, scale: 3)
            if let c = model.activeClient {
                VStack(alignment: .leading, spacing: 2) {
                    Text(projectsEnabled && model.activeProject != nil ? "\(c.name) · \(model.activeProject!.name)" : c.name)
                        .font(.headline).lineLimit(1)
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
        if justStopped { return tr("Klaar! Mooi werk.") }
        return model.clients.isEmpty ? tr("Voeg je eerste klant toe.") : tr("Geen timer actief.")
    }

    private func row(_ title: LocalizedStringKey, _ seconds: TimeInterval) -> some View {
        HStack { Text(title); Spacer(); Text(Format.short(seconds)).monospacedDigit() }
    }

    private func releaseFocus() {
        newClientFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private func add() {
        if model.addClient(name: newClient) { newClient = "" }
    }
}

/// One client row: the whole row is clickable, and highlights on hover to show that.
/// A client with projects gets a chevron that lists "No project" plus its projects.
private struct ClientRow: View {
    let client: Client
    let isRunning: Bool
    let today: TimeInterval
    let animated: Bool
    let projects: [Project]
    let runningProjectId: UUID?
    let expanded: Bool
    let onToggleExpand: () -> Void
    let onPick: (Project?) -> Void
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Button(action: action) {
                    HStack {
                        Image(systemName: isRunning ? "stop.circle.fill" : "play.circle").font(.title2)
                        Text(client.name).font(.title3).lineLimit(1)
                        Spacer()
                        Text(Format.short(today)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if !projects.isEmpty {
                    Button(action: onToggleExpand) {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary).padding(.leading, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Projecten"))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(hovering ? 0.10 : (isRunning ? 0.06 : 0)))
            )
            .onHover { hovering = $0 }
            .animation(animated ? .easeOut(duration: 0.12) : nil, value: hovering)

            if expanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(projects) { pick($0, title: LocalizedStringKey($0.name)) }
                    pick(nil, title: "Algemeen werk")
                }
                .padding(.leading, 34)
            }
        }
    }

    private func pick(_ project: Project?, title: LocalizedStringKey) -> some View {
        let current = isRunning && runningProjectId == project?.id
        return Button { onPick(project) } label: {
            HStack {
                Image(systemName: "checkmark").opacity(current ? 1 : 0).font(.caption)
                if let project { Text(verbatim: project.name) } else { Text(title).foregroundStyle(.secondary) }
                Spacer()
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Reorders clients by drag and drop. Reports a move (not copy) so the cursor shows no green plus.
private struct ClientDrop: DropDelegate {
    let target: UUID
    let model: AppModel
    @Binding var dragging: UUID?
    @Binding var dropTarget: UUID?

    func dropEntered(info: DropInfo) { dropTarget = target }
    func dropExited(info: DropInfo) { if dropTarget == target { dropTarget = nil } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        defer { dragging = nil; dropTarget = nil }
        guard let id = dragging else { return false }
        model.moveClient(id, to: target)
        return true
    }
}
