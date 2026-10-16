import SwiftUI
import LittleWorksCore

/// Shown right after a timer stops: what did you do in that time?
struct NotePrompt: View {
    let model: AppModel
    let entry: TimeEntry
    @State private var note: String
    @FocusState private var focused: Bool

    init(model: AppModel, entry: TimeEntry) {
        self.model = model
        self.entry = entry
        _note = State(initialValue: entry.note ?? "")
    }

    private var clientName: String {
        model.allClients.first { $0.id == entry.clientId }?.name ?? "Klant"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Notitie bij \(clientName)").font(.headline)
                Text("\(Format.short(entry.duration(at: Date()))) gewerkt · \(entry.startTime.formatted(date: .omitted, time: .shortened)) – \((entry.endTime ?? Date()).formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
            }
            TextField("Wat heb je gedaan? Of andere opmerkingen", text: $note, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(save)
            HStack {
                Button("Overslaan") { model.dismissNotePrompt() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Bewaar", action: save).keyboardShortcut(.defaultAction)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .onAppear { focused = true }
    }

    private func save() { model.saveNote(note, for: entry.id) }
}
