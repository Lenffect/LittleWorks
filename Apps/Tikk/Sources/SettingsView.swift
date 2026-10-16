import AppKit
import SwiftUI
import LittleWorksCore

struct SettingsView: View {
    let model: AppModel
    @AppStorage(SettingsKey.showUrencriterium) private var show = true
    @AppStorage(SettingsKey.urencriteriumTarget) private var target = SettingsKey.defaultTarget
    @AppStorage(SettingsKey.askNoteOnStop) private var askNote = true
    @AppStorage(SettingsKey.autoBackupEnabled) private var autoBackup = true
    @AppStorage(SettingsKey.autoBackupPath) private var backupPath = SettingsKey.defaultBackupPath

    @State private var deleting: Client?
    @State private var notificationStatus = ""
    @AppStorage(ReminderSettings.enabledKey) private var remind = false
    @AppStorage(ReminderSettings.firstKey) private var remindFirst = ReminderSettings.defaultFirst
    @AppStorage(ReminderSettings.everyKey) private var remindEvery = ReminderSettings.defaultEvery

    var body: some View {
        if let client = deleting {
            DeleteClientConfirm(model: model, client: client) { deleting = nil }
        } else {
            form
        }
    }

    private var form: some View {
        Form {
            Section("Urencriterium") {
                Toggle("Urencriterium tonen", isOn: $show)
                HStack {
                    Text("Doel (uren per jaar)")
                    Spacer()
                    TextField("", value: $target, format: .number.grouping(.never))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                }
                .disabled(!show)
            }

            Section("Herinnering") {
                Toggle("Vraag of ik nog werk aan de klant", isOn: $remind)
                    .onChange(of: remind) { if remind { NotificationService.shared.requestPermission() } }
                Stepper("Eerste herinnering na \(remindFirst) min", value: $remindFirst, in: 1...480, step: 5)
                    .disabled(!remind)
                Stepper("Daarna elke \(remindEvery) min", value: $remindEvery, in: 1...480, step: 5)
                    .disabled(!remind)
                HStack {
                    Button("Stuur testmelding") { model.sendTestReminder() }
                    Spacer()
                    Text(notificationStatus).font(.caption).foregroundStyle(.secondary)
                }
                .task { notificationStatus = await NotificationService.shared.statusText() }
            }

            Section("Back-up") {
                Toggle("Automatisch back-uppen bij elke wijziging", isOn: $autoBackup)
                    .onChange(of: autoBackup) { model.autoBackup() }
                LabeledContent("Map") {
                    Text(backupPath).font(.caption).lineLimit(2).truncationMode(.middle)
                }
                HStack {
                    Button("Kies map…", action: chooseFolder)
                    Button("iCloud Drive") { setPath(NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs/Tikk") }
                    Button("Standaard") { setPath(SettingsKey.defaultBackupPath) }
                }
                .disabled(!autoBackup)
                if let status = model.autoBackupStatus {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Button("Back-up maken als bestand…") { model.exportBackup() }
                if let m = model.statusMessage { Text(m).font(.caption).foregroundStyle(.secondary) }
            }

            Section("Gearchiveerde klanten") {
                if model.archivedClients.isEmpty {
                    Text("Geen gearchiveerde klanten.").foregroundStyle(.secondary)
                }
                ForEach(model.archivedClients) { client in
                    HStack {
                        Text(client.name)
                        Spacer()
                        Button("Herstel") { model.unarchive(client) }
                        Button("Verwijder…", role: .destructive) { deleting = client }
                    }
                }
            }

            Section("Algemeen") {
                Toggle("Vraag om een notitie bij stoppen", isOn: $askNote)
                Toggle("Start bij inloggen", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
            }
        }
        .formStyle(.grouped)
    }

    private func setPath(_ path: String) {
        backupPath = path
        model.autoBackup()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Kies"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { setPath(url.path) }
    }
}

/// Type the client's name to confirm a permanent delete.
private struct DeleteClientConfirm: View {
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
        .onAppear { focused = true }
    }

    private func delete() {
        guard matches else { return }
        model.deleteClientPermanently(client)
        onDone()
    }
}
