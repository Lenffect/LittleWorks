import SwiftUI
import LittleWorksCore

/// Type the client's name to confirm a permanent delete.
struct DeleteClientConfirm: View {
    let model: AppModel
    let client: Client
    let onDone: () -> Void
    @State private var typed = ""
    @FocusState private var focused: Bool

    private var matches: Bool { typed.trimmingCharacters(in: .whitespaces) == client.name }

    var body: some View {
        let usage = model.usage(of: client.id)
        VStack(alignment: .leading, spacing: 14) {
            Text("\(client.name) definitief verwijderen").font(.headline)
            Text("Dit verwijdert de klant en **\(usage.count) registraties** (\(Format.short(usage.seconds)) uur) voorgoed. Dit kan niet ongedaan worden gemaakt, ook niet via de automatische back-up: die wordt direct overschreven. Maak eerst een back-up als bestand als je dit wilt kunnen terugdraaien.")
                .foregroundStyle(.secondary)
            Text("Typ de naam van de klant om te bevestigen:")
            TextField(client.name, text: $typed)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(delete)
            HStack {
                Button("Annuleer", action: onDone).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Definitief verwijderen", role: .destructive, action: delete)
                    .disabled(!matches)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 420)
        .onAppear { focused = true }
    }

    private func delete() {
        guard matches else { return }
        model.deleteClientPermanently(client)
        onDone()
    }
}
