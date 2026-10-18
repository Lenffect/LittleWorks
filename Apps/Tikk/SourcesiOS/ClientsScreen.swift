import SwiftUI
import LittleWorksCore

struct ClientsScreen: View {
    let model: AppModel
    @State private var newClient = ""
    @State private var deleting: Client?

    var body: some View {
        let _ = model.dataVersion   // refresh when data changes
        let archived = model.archivedClients
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Nieuwe klant", text: $newClient).onSubmit(add)
                            .onChange(of: newClient) { model.errorMessage = nil }
                        Button("Voeg toe", action: add)
                            .disabled(newClient.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let e = model.errorMessage { Text(e).foregroundStyle(.red).font(.caption) }
                }
                Section("Actief") {
                    if model.clients.isEmpty { Text("Nog geen klanten.").foregroundStyle(.secondary) }
                    ForEach(model.clients) { client in
                        NavigationLink(value: client.id) { Text(client.name) }
                            .swipeActions(edge: .trailing) {
                                Button("Archiveer") { model.archive(client) }.tint(.orange)
                            }
                    }
                    .onMove { from, to in
                        var ids = model.clients.map(\.id)
                        ids.move(fromOffsets: from, toOffset: to)
                        model.setClientOrder(ids)
                    }
                }
                if !archived.isEmpty {
                    Section("Gearchiveerd") {
                        ForEach(archived) { client in
                            HStack {
                                Text(client.name).foregroundStyle(.secondary)
                                Spacer()
                                Button("Herstel") { model.unarchive(client) }.buttonStyle(.borderless)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Verwijder…", role: .destructive) { deleting = client }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Klanten")
            .toolbar { EditButton() }
            .navigationDestination(for: UUID.self) { id in ClientDetailScreen(model: model, clientId: id) }
            .sheet(item: $deleting) { client in DeleteClientSheet(model: model, client: client) { deleting = nil } }
        }
    }

    private func add() {
        if model.addClient(name: newClient) { newClient = "" }
    }
}

/// Name, rates and projects of one client.
struct ClientDetailScreen: View {
    let model: AppModel
    let clientId: UUID
    @AppStorage(SettingsKey.projectsEnabled) private var projectsEnabled = false
    @State private var name = ""
    @State private var rate: Decimal?
    @State private var fee: Decimal?
    @State private var loaded = false
    @State private var newProject = ""
    @Environment(\.dismiss) private var dismiss

    private var client: Client? { model.allClients.first { $0.id == clientId } }

    var body: some View {
        let _ = model.dataVersion
        Form {
            if let client {
                Section("Naam") {
                    TextField("Naam", text: $name)
                        .onSubmit { model.renameClient(client, to: name) }
                    if let e = model.errorMessage { Text(e).foregroundStyle(.red).font(.caption) }
                }
                Section {
                    HStack {
                        Text("Uurloon")
                        Spacer()
                        Text("€")
                        TextField("uurloon", value: $rate, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                        Text("/u").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Vast bedrag")
                        Spacer()
                        Text("€")
                        TextField("vast/mnd", value: $fee, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                        Text("/mnd").foregroundStyle(.secondary)
                    }
                    if let fee, fee > 0 { Text(effectiveRate(fee: fee)).font(.caption).foregroundStyle(.secondary) }
                }
                if projectsEnabled { projectsSection(client) }
                Section {
                    Button("Archiveer") { model.archive(client); dismiss() }
                }
            }
        }
        .navigationTitle(client?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded, let client else { return }
            name = client.name; rate = client.hourlyRate; fee = client.monthlyFee
            model.errorMessage = nil
            loaded = true
        }
        .onChange(of: rate) { if loaded { model.setRate(rate, for: clientId) } }
        .onChange(of: fee) { if loaded { model.setMonthlyFee(fee, for: clientId) } }
        .onDisappear { if let client, name != client.name { model.renameClient(client, to: name) } }
    }

    private func effectiveRate(fee: Decimal) -> String {
        let seconds = model.monthSeconds()[clientId] ?? 0
        let hours = seconds / 3600
        guard hours > 0 else { return tr("Deze maand nog geen uren") }
        let perHour = NSDecimalNumber(decimal: fee).doubleValue / hours
        let amount = perHour.formatted(.number.precision(.fractionLength(2)).locale(L10n.language.locale))
        return tr("Deze maand: %@ u → effectief € %@/u", Format.short(seconds), amount)
    }

    @ViewBuilder private func projectsSection(_ client: Client) -> some View {
        let projects = model.allProjects.filter { $0.clientId == clientId }
        let seconds = model.projectSeconds()
        Section("Projecten") {
            if projects.filter({ !$0.isArchived }).isEmpty {
                Text("Nog geen projecten bij deze klant.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(projects.filter { !$0.isArchived }) { project in
                NavigationLink {
                    ProjectEditScreen(model: model, project: project, clientRate: client.hourlyRate)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                        Text(summary(project, clientRate: client.hourlyRate, seconds: seconds[project.id] ?? 0))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                TextField("Naam van het project", text: $newProject).onSubmit(addProject)
                    .onChange(of: newProject) { model.errorMessage = nil }
                Button("Project toevoegen", action: addProject)
                    .disabled(newProject.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        let archived = projects.filter(\.isArchived)
        if !archived.isEmpty {
            Section("Gearchiveerde projecten") {
                ForEach(archived) { project in
                    HStack {
                        Text(project.name).foregroundStyle(.secondary)
                        Spacer()
                        Button("Herstel") { var p = project; p.isArchived = false; model.updateProject(p) }
                            .buttonStyle(.borderless)
                    }
                    .swipeActions { Button("Verwijder…", role: .destructive) { model.deleteProject(project) } }
                }
            }
        }
    }

    private func addProject() {
        if model.addProject(clientId: clientId, name: newProject) { newProject = "" }
    }
}

func projectSummary(_ project: Project, clientRate: Decimal?, seconds: TimeInterval) -> String {
    let s = ProjectMath.stats(for: project, clientRate: clientRate, seconds: seconds)
    var parts = [tr("%@ u", Format.short(s.seconds))]
    if let progress = s.progress, let est = project.estimatedHours {
        parts.append(tr("%lld%% van %@ u", Int(progress * 100), est.formatted(.number.locale(L10n.language.locale))))
    }
    switch project.kind {
    case .fixed: if let r = s.effectiveRate { parts.append(tr("effectief €%@/u", money(r))) }
    case .hourly: if let r = s.revenue { parts.append(tr("omzet €%@", money(r))) }
    }
    return parts.joined(separator: " · ")
}

private func summary(_ p: Project, clientRate: Decimal?, seconds: TimeInterval) -> String {
    projectSummary(p, clientRate: clientRate, seconds: seconds)
}

struct ProjectEditScreen: View {
    let model: AppModel
    let project: Project
    let clientRate: Decimal?
    @State private var name: String
    @State private var kind: ProjectKind
    @State private var price: Decimal?
    @State private var estimate: Double?
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, project: Project, clientRate: Decimal?) {
        self.model = model
        self.project = project
        self.clientRate = clientRate
        _name = State(initialValue: project.name)
        _kind = State(initialValue: project.kind)
        _price = State(initialValue: project.price)
        _estimate = State(initialValue: project.estimatedHours)
    }

    var body: some View {
        Form {
            Section {
                TextField("Naam", text: $name)
                Picker("Soort", selection: $kind) {
                    Text("Per uur").tag(ProjectKind.hourly)
                    Text("Vaste prijs").tag(ProjectKind.fixed)
                }
                HStack {
                    Text(kind == .fixed ? "Totaalprijs" : "Uurtarief")
                    Spacer()
                    Text("€")
                    TextField(kind == .fixed ? "totaalprijs" : "uurtarief", value: $price, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                }
                HStack {
                    Text("Schatting")
                    Spacer()
                    TextField("schatting", value: $estimate, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                    Text("u").foregroundStyle(.secondary)
                }
            }
            Section {
                Text(projectSummary(project, clientRate: clientRate, seconds: model.projectSeconds()[project.id] ?? 0))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("Archiveer") { var p = current(); p.isArchived = true; model.updateProject(p); dismiss() }
                Button("Verwijderen", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { commit() }
        .confirmationDialog("Project verwijderen?", isPresented: $confirmDelete) {
            Button("Verwijderen", role: .destructive) { model.deleteProject(project); dismiss() }
        } message: {
            Text("De uren blijven bewaard bij de klant, maar zonder project.")
        }
    }

    private func current() -> Project {
        var p = project
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        p.name = trimmed.isEmpty ? project.name : trimmed
        p.kind = kind; p.price = price
        p.estimatedHours = estimate.flatMap { $0 > 0 ? $0 : nil }
        return p
    }

    private func commit() {
        let p = current()
        if p != project { model.updateProject(p) }
    }
}

/// Type the client's name to confirm a permanent delete.
struct DeleteClientSheet: View {
    let model: AppModel
    let client: Client
    let onDone: () -> Void
    @State private var typed = ""

    private var matches: Bool { typed.trimmingCharacters(in: .whitespaces) == client.name }

    var body: some View {
        let usage = model.usage(of: client.id)
        NavigationStack {
            Form {
                Section {
                    Text("Dit verwijdert de klant en **\(usage.count) registraties** (\(Format.short(usage.seconds)) uur) voorgoed. Dit kan niet ongedaan worden gemaakt, ook niet via de automatische back-up: die wordt direct overschreven. Maak eerst een back-up als bestand als je dit wilt kunnen terugdraaien.")
                        .foregroundStyle(.secondary)
                }
                Section("Typ de naam van de klant om te bevestigen:") {
                    TextField(client.name, text: $typed).autocorrectionDisabled()
                }
                Section {
                    Button("Definitief verwijderen", role: .destructive) {
                        model.deleteClientPermanently(client); onDone()
                    }
                    .disabled(!matches)
                }
            }
            .navigationTitle("\(client.name) definitief verwijderen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuleer", action: onDone) } }
        }
    }
}
