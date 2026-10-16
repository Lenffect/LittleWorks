import SwiftUI
import LittleWorksCore

/// Client name shown as plain text; the pencil icon switches to an editable field.
/// Return or the checkmark saves, Escape cancels. A rejected name reverts.
private struct ClientNameField: View {
    let model: AppModel
    let client: Client
    @State private var editing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if editing {
                TextField("Naam", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .focused($focused)
                    .onSubmit(commit)
                    .onExitCommand(perform: cancel)
                Button(action: commit) { Image(systemName: "checkmark") }
                    .buttonStyle(.borderless)
                    .help(tr("Opslaan"))
            } else {
                Text(client.name)
                Button(action: edit) { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help(tr("Naam wijzigen"))
            }
        }
    }

    private func edit() {
        text = client.name
        model.errorMessage = nil
        editing = true
        focused = true
    }

    private func commit() {
        if model.renameClient(client, to: text) { editing = false }
    }

    private func cancel() {
        model.errorMessage = nil
        editing = false
    }
}

/// Client management: add, rename, hourly rate, archive, restore, delete.
struct ClientsView: View {
    let model: AppModel
    @State private var newClient = ""
    @State private var deleting: Client?
    @AppStorage(SettingsKey.projectsEnabled) private var projectsEnabled = false

    var body: some View {
        let _ = model.dataVersion   // refresh when data changes
        let active = model.allClients.filter { !$0.isArchived }
        let archived = model.archivedClients
        let month = model.monthSeconds()
        List {
            if !projectsEnabled {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Werk je met projecten?").font(.headline)
                            Text("Geef een klus een vaste prijs of eigen tarief, een schatting en een effectief uurtarief.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Projecten aanzetten") { projectsEnabled = true }
                    }
                }
            }
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
                if active.isEmpty { Text("Nog geen klanten.").foregroundStyle(.secondary) }
                ForEach(active) { client in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            ClientNameField(model: model, client: client)
                            Spacer()
                            RateField(client: client) { model.setRate($0, for: client.id) }
                            FeeField(client: client) { model.setMonthlyFee($0, for: client.id) }
                            Button("Archiveer") { model.archive(client) }
                        }
                        if let fee = client.monthlyFee, fee > 0 {
                            Text(effectiveRate(fee: fee, seconds: month[client.id] ?? 0))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if projectsEnabled {
                            ClientProjects(model: model, client: client)
                        }
                    }
                }
            }
            Section("Gearchiveerd") {
                if archived.isEmpty { Text("Geen gearchiveerde klanten.").foregroundStyle(.secondary) }
                ForEach(archived) { client in
                    HStack {
                        ClientNameField(model: model, client: client)
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

    private func effectiveRate(fee: Decimal, seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        guard hours > 0 else { return tr("Deze maand nog geen uren") }
        let perHour = NSDecimalNumber(decimal: fee).doubleValue / hours
        let amount = perHour.formatted(.number.precision(.fractionLength(2)).locale(L10n.language.locale))
        return tr("Deze maand: %@ u → effectief € %@/u", Format.short(seconds), amount)
    }

    private func add() {
        if model.addClient(name: newClient) { newClient = "" }
    }
}
