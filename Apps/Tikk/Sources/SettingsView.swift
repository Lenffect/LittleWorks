import AppKit
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @AppStorage(SettingsKey.showUrencriterium) private var show = true
    @AppStorage(SettingsKey.urencriteriumTarget) private var target = SettingsKey.defaultTarget
    @AppStorage(SettingsKey.askNoteOnStop) private var askNote = true
    @AppStorage(SettingsKey.autoBackupEnabled) private var autoBackup = true
    @AppStorage(SettingsKey.autoBackupPath) private var backupPath = SettingsKey.defaultBackupPath

    var body: some View {
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
