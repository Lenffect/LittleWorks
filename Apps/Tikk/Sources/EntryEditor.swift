import SwiftUI
import LittleWorksCore

struct EntryEditor: View {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Registratie aanpassen").font(.headline)
            Picker("Klant", selection: $clientId) {
                ForEach(model.allClients) { Text($0.name).tag($0.id) }
            }
            if projectsEnabled {
                let choices = model.allProjects.filter { $0.clientId == clientId && (!$0.isArchived || $0.id == original.projectId) }
                Picker("Project", selection: $projectId) {
                    ForEach(choices) { Text($0.name).tag(UUID?.some($0.id)) }
                    Divider()
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
            TextField("Notitie", text: $note)
            if let e = model.errorMessage { Text(e).foregroundStyle(.red).font(.caption) }
            HStack {
                Button("Verwijderen", role: .destructive) { confirmDelete = true }
                Spacer()
                Button("Annuleer", action: onDone).keyboardShortcut(.cancelAction)
                Button("Bewaar", action: save).keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 380)
        .confirmationDialog("Deze registratie verwijderen?", isPresented: $confirmDelete) {
            Button("Verwijderen", role: .destructive) { model.deleteEntry(id: original.id); onDone() }
        }
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
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        e.note = trimmed.isEmpty ? nil : trimmed
        model.errorMessage = nil
        if model.updateEntry(e) { onDone() }
    }
}
