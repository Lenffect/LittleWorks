import SwiftUI
import LittleWorksCore

/// Client management: add, hourly rate, archive, restore, delete.
struct ClientsView: View {
    let model: AppModel
    @State private var newClient = ""
    @State private var deleting: Client?

    var body: some View {
        let _ = model.dataVersion   // refresh when data changes
        let active = model.allClients.filter { !$0.isArchived }
        let archived = model.archivedClients
        List {
            Section {
                HStack {
                    TextField("Nieuwe klant", text: $newClient).onSubmit(add)
                    Button("Voeg toe", action: add)
                        .disabled(newClient.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("Actief") {
                if active.isEmpty { Text("Nog geen klanten.").foregroundStyle(.secondary) }
                ForEach(active) { client in
                    HStack {
                        Text(client.name)
                        Spacer()
                        RateField(client: client) { model.setRate($0, for: client.id) }
                        Button("Archiveer") { model.archive(client) }
                    }
                }
            }
            Section("Gearchiveerd") {
                if archived.isEmpty { Text("Geen gearchiveerde klanten.").foregroundStyle(.secondary) }
                ForEach(archived) { client in
                    HStack {
                        Text(client.name)
                        Spacer()
                        Button("Herstel") { model.unarchive(client) }
                        Button("Verwijder…", role: .destructive) { deleting = client }
                    }
                }
            }
        }
        .sheet(item: $deleting) { client in
            DeleteClientConfirm(model: model, client: client) { deleting = nil }
        }
    }

    private func add() {
        model.addClient(name: newClient)
        newClient = ""
    }
}
