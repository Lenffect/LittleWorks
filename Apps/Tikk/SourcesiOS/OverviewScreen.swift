import SwiftUI
import LittleWorksCore

struct OverviewScreen: View {
    let model: AppModel
    @State private var days: [DayGroup] = []
    @State private var projectRows: [ProjectStatus] = []
    @State private var editing: EditTarget?
    @AppStorage(SettingsKey.projectsEnabled) private var projectsEnabled = false

    struct EditTarget: Identifiable { let id: UUID }

    private var refreshKey: String {
        "\(Int(model.now.timeIntervalSince1970 / 60))-\(model.active?.id.uuidString ?? "-")-\(model.dataVersion)"
    }

    var body: some View {
        NavigationStack {
            Group {
                if days.isEmpty {
                    VStack(spacing: 10) {
                        TikkFigure(pose: .leeg, scale: 4)
                        Text("Nog geen registraties.").font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section { UrencriteriumBar(yearSeconds: model.yearTotal) }
                        if projectsEnabled && !projectRows.isEmpty {
                            Section { ProjectStatusBlock(rows: projectRows) }
                                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                        }
                        ForEach(days) { group in
                            Section {
                                ForEach(group.rows) { row in
                                    Button { editing = EditTarget(id: row.entryId) } label: { rowView(row) }
                                        .buttonStyle(.plain)
                                }
                            } header: {
                                HStack {
                                    Text(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                    Spacer()
                                    Text(Format.short(group.total)).monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Overzicht")
            .task(id: refreshKey) { days = model.overviewDays(); projectRows = model.projectStatuses() }
            .sheet(item: $editing) { target in
                if let entry = model.entry(id: target.id) {
                    EntryEditorScreen(model: model, entry: entry) { editing = nil }
                }
            }
        }
    }

    private func rowView(_ row: DayRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(projectsEnabled ? (row.projectName.map { "\(row.clientName) · \($0)" } ?? row.clientName) : row.clientName)
                if let n = row.note { Text(n).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                Text("\(row.start.formatted(date: .omitted, time: .shortened)) – \(row.isRunning ? tr("nu") : row.end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.short(row.duration)).monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}

struct EntryEditorScreen: View {
    let model: AppModel
    let original: TimeEntry
    let onDone: () -> Void

    @State private var clientId: UUID
    @State private var projectId: UUID?
    @AppStorage(SettingsKey.projectsEnabled) private var projectsEnabled = false
    @State private var start: Date
    @State private var end: Date
    @State private var note: String
    @State private var confirmDelete = false

    init(model: AppModel, entry: TimeEntry, onDone: @escaping () -> Void) {
        self.model = model
        self.original = entry
        self.onDone = onDone
        _clientId = State(initialValue: entry.clientId)
        _projectId = State(initialValue: entry.projectId)
        _start = State(initialValue: entry.startTime)
        _end = State(initialValue: entry.endTime ?? Date())
        _note = State(initialValue: entry.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Klant", selection: $clientId) {
                    ForEach(model.allClients) { Text($0.name).tag($0.id) }
                }
                if projectsEnabled {
                    let choices = model.allProjects.filter { $0.clientId == clientId && (!$0.isArchived || $0.id == original.projectId) }
                    Picker("Project", selection: $projectId) {
                        ForEach(choices) { Text($0.name).tag(UUID?.some($0.id)) }
                        Text("Algemeen werk").tag(UUID?.none)
                    }
                    .onChange(of: clientId) {
                        if !model.allProjects.contains(where: { $0.id == projectId && $0.clientId == clientId }) { projectId = nil }
                    }
                    .onChange(of: projectId) { old, new in swapNotePrefix(from: old, to: new) }
                }
                DatePicker("Start", selection: $start)
                if original.isActive {
                    Text("Timer loopt nog; stop eerst om het eind aan te passen.").font(.caption).foregroundStyle(.secondary)
                } else {
                    DatePicker("Eind", selection: $end)
                }
                TextField("Notitie", text: $note, axis: .vertical)
                if let e = model.errorMessage { Text(e).foregroundStyle(.red).font(.caption) }
                Section {
                    Button("Verwijderen", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle("Registratie aanpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleer", action: onDone) }
                ToolbarItem(placement: .confirmationAction) { Button("Bewaar", action: save) }
            }
            .confirmationDialog("Deze registratie verwijderen?", isPresented: $confirmDelete) {
                Button("Verwijderen", role: .destructive) { model.deleteEntry(id: original.id); onDone() }
            }
        }
        .onAppear { model.errorMessage = nil }
    }

    /// Keeps the automatic "Project:" note prefix in line when the project is changed.
    private func swapNotePrefix(from old: UUID?, to new: UUID?) {
        let all = model.allProjects
        let oldPrefix = all.first { $0.id == old }.map { $0.name + ":" }
        let newPrefix = all.first { $0.id == new }.map { $0.name + ":" }
        if let oldPrefix, note.hasPrefix(oldPrefix) {
            let rest = String(note.dropFirst(oldPrefix.count))
            note = newPrefix.map { $0 + rest } ?? rest.trimmingCharacters(in: .whitespaces)
        } else if let newPrefix, note.trimmingCharacters(in: .whitespaces).isEmpty {
            note = newPrefix
        }
    }

    private func save() {
        var e = original
        e.clientId = clientId
        if projectsEnabled { e.projectId = projectId }
        e.startTime = start
        if !original.isActive { e.endTime = end }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        e.note = trimmed.isEmpty ? nil : trimmed
        model.errorMessage = nil
        if model.updateEntry(e) { onDone() }
    }
}
