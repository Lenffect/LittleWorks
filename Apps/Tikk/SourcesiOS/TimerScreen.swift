import SwiftUI
import LittleWorksCore

/// Main screen: the running timer and one big button per client.
struct TimerScreen: View {
    let model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    UrencriteriumBar(yearSeconds: model.yearTotal)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.05)))
                    if model.clients.isEmpty {
                        Text("Nog geen klanten.").foregroundStyle(.secondary).padding(.top, 24)
                    }
                    ForEach(model.clients) { client in
                        ClientButton(model: model, client: client)
                    }
                }
                .padding(16)
            }
            .background(Brand.background)
            .navigationTitle("tikk.")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: Binding(
                get: { model.notePromptEntryId != nil },
                set: { if !$0 { model.dismissNotePrompt() } })
            ) {
                if let id = model.notePromptEntryId, let entry = model.entry(id: id) {
                    NotePrompt(model: model, entry: entry).presentationDetents([.medium])
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            TikkFigure(pose: poseForHeader, scale: 5)
            if let client = model.activeClient {
                Text(model.activeProject.map { "\(client.name) · \($0.name)" } ?? client.name).font(.headline)
                Text(Format.duration(model.activeElapsed))
                    .font(.system(size: 44, weight: .semibold, design: .rounded)).monospacedDigit()
            } else {
                Text(model.clients.isEmpty ? "Voeg je eerste klant toe." : "Tik op een klant om te starten").font(.headline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 24) {
                total("Vandaag", model.todayTotal)
                total("Deze week", model.weekTotal)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var poseForHeader: TikkPose {
        if model.active != nil { return Int(model.now.timeIntervalSince1970) % 2 == 0 ? .werkA : .werkB }
        if let stopped = model.lastStopped, model.now.timeIntervalSince(stopped) < 5 { return .klaar }
        return .slaap
    }

    private func total(_ title: LocalizedStringKey, _ seconds: TimeInterval) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(Format.short(seconds)).font(.title3.weight(.semibold)).monospacedDigit()
        }
    }
}

private struct ClientButton: View {
    let model: AppModel
    let client: Client
    @AppStorage(SettingsKey.projectsEnabled) private var projectsEnabled = false
    @State private var expanded = false

    var body: some View {
        let _ = model.dataVersion
        let running = model.active?.clientId == client.id
        let projects = projectsEnabled ? model.allProjects.filter { $0.clientId == client.id && !$0.isArchived } : []
        VStack(spacing: 4) {
            Button {
                if running { model.stop(); expanded = false }
                else if projects.isEmpty { model.toggle(client) }
                else { withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() } }
            } label: {
                HStack {
                    Image(systemName: running ? "stop.circle.fill" : "play.circle.fill").font(.title)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(client.name).font(.title3.weight(.semibold)).lineLimit(1)
                        if running, let p = model.activeProject, projectsEnabled {
                            Text(p.name).font(.caption).lineLimit(1).opacity(0.85)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        if running { Text(Format.duration(model.activeElapsed)).monospacedDigit() }
                        Text(Format.short(model.todayByClient[client.id] ?? 0)).font(.caption).monospacedDigit()
                            .opacity(running ? 0.8 : 0.6)
                    }
                    if !projects.isEmpty && !running {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .foregroundStyle(running ? Color.white : Brand.ink)
                .background(RoundedRectangle(cornerRadius: 16).fill(running ? Color.accentColor : Color.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact, trigger: running)

            if expanded && !running {
                VStack(spacing: 0) {
                    ForEach(projects) { project in pick(project, title: project.name) }
                    pick(nil, title: tr("Algemeen werk"))
                }
                .padding(.leading, 24)
            }
        }
    }

    private func pick(_ project: Project?, title: String) -> some View {
        Button {
            model.start(client, project: project)
            expanded = false
        } label: {
            HStack {
                Image(systemName: "play.fill").font(.caption)
                Text(verbatim: title).foregroundStyle(project == nil ? .secondary : Brand.ink)
                Spacer()
            }
            .padding(.vertical, 12).padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
