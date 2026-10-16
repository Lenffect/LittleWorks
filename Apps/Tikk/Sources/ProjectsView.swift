import SwiftUI
import LittleWorksCore

func money(_ d: Decimal) -> String {
    d.formatted(.number.precision(.fractionLength(2)).locale(L10n.language.locale))
}

/// Projects of one client, shown under the client in the Clients page.
struct ClientProjects: View {
    let model: AppModel
    let client: Client
    @State private var newName = ""
    @State private var adding = false
    @FocusState private var nameFocused: Bool
    @State private var deleting: Project?

    var body: some View {
        let _ = model.dataVersion
        let projects = model.allProjects.filter { $0.clientId == client.id }
        let active = projects.filter { !$0.isArchived }
        let archived = projects.filter(\.isArchived)
        let seconds = model.projectSeconds()

        VStack(alignment: .leading, spacing: 6) {
            Text("Projecten").font(.subheadline.weight(.semibold)).padding(.top, 4)
            if active.isEmpty && !adding { Text("Nog geen projecten bij deze klant.").font(.caption).foregroundStyle(.secondary) }
            ForEach(active) { project in
                ProjectRow(project: project, clientRate: client.hourlyRate, seconds: seconds[project.id] ?? 0,
                           onChange: model.updateProject) {
                    var p = project; p.isArchived = true; model.updateProject(p)
                }
            }
            if adding {
                HStack {
                    TextField("Naam van het project", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .focused($nameFocused)
                        .onSubmit(add)
                        .onChange(of: newName) { model.errorMessage = nil }
                    Button("Voeg toe", action: add)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Annuleer") { adding = false; newName = ""; model.errorMessage = nil }
                }
            } else {
                Button { adding = true; nameFocused = true } label: {
                    Label("Project toevoegen", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
            }
            if !archived.isEmpty {
                Text("Gearchiveerde projecten").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                ForEach(archived) { project in
                    HStack {
                        Text(project.name).foregroundStyle(.secondary)
                        Spacer()
                        Button("Herstel") { var p = project; p.isArchived = false; model.updateProject(p) }
                        Button("Verwijder…", role: .destructive) { deleting = project }
                    }
                    .font(.callout)
                }
            }
        }
        .padding(.leading, 12)
        .confirmationDialog("Project verwijderen?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Verwijderen", role: .destructive) { if let p = deleting { model.deleteProject(p) }; deleting = nil }
        } message: {
            Text("De uren blijven bewaard bij de klant, maar zonder project.")
        }
    }

    private func add() {
        if model.addProject(clientId: client.id, name: newName) { newName = ""; adding = false }
    }
}

private struct ProjectRow: View {
    let project: Project
    let clientRate: Decimal?
    let seconds: TimeInterval
    let onChange: (Project) -> Void
    let onArchive: () -> Void

    @State private var name: String
    @State private var kind: ProjectKind
    @State private var price: Decimal?
    @State private var estimate: Double?

    init(project: Project, clientRate: Decimal?, seconds: TimeInterval,
         onChange: @escaping (Project) -> Void, onArchive: @escaping () -> Void) {
        self.project = project
        self.clientRate = clientRate
        self.seconds = seconds
        self.onChange = onChange
        self.onArchive = onArchive
        _name = State(initialValue: project.name)
        _kind = State(initialValue: project.kind)
        _price = State(initialValue: project.price)
        _estimate = State(initialValue: project.estimatedHours)
    }

    var body: some View {
        let stats = ProjectMath.stats(for: project, clientRate: clientRate, seconds: seconds)
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                TextField("Naam", text: $name).onChange(of: name) { commit() }
                Picker("", selection: $kind) {
                    Text("Per uur").tag(ProjectKind.hourly)
                    Text("Vaste prijs").tag(ProjectKind.fixed)
                }
                .labelsHidden().frame(width: 110)
                .onChange(of: kind) { commit() }
                HStack(spacing: 2) {
                    Text("€")
                    if kind == .fixed {
                        TextField("totaalprijs", value: $price, format: .number)
                            .multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(width: 80)
                            .onChange(of: price) { commit() }
                    } else {
                        TextField("uurtarief", value: $price, format: .number)
                            .multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(width: 80)
                            .onChange(of: price) { commit() }
                        Text("/u").foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 2) {
                    TextField("schatting", value: $estimate, format: .number)
                        .multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(width: 56)
                        .onChange(of: estimate) { commit() }
                    Text("u").foregroundStyle(.secondary)
                }
                Button("Archiveer", action: onArchive)
            }
            Text(summary(stats))
                .font(.caption)
                .foregroundStyle((stats.progress ?? 0) > 1 ? Color.red : Color.secondary)
        }
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var p = project
        p.name = trimmed; p.kind = kind; p.price = price
        p.estimatedHours = estimate.flatMap { $0 > 0 ? $0 : nil }
        onChange(p)
    }

    private func summary(_ s: ProjectStats) -> String {
        var parts = [tr("%@ u", Format.short(s.seconds))]
        if let progress = s.progress, let est = project.estimatedHours {
            parts.append(tr("%lld%% van %@ u", Int(progress * 100), est.formatted(.number.locale(L10n.language.locale))))
        }
        switch project.kind {
        case .fixed:
            if let r = s.effectiveRate { parts.append(tr("effectief €%@/u", money(r))) }
        case .hourly:
            if let r = s.revenue { parts.append(tr("omzet €%@", money(r))) }
        }
        return parts.joined(separator: " · ")
    }
}
