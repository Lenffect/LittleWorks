import AppKit
import SwiftUI
import LittleWorksCore

struct SettingsView: View {
    let model: AppModel
    @AppStorage(SettingsKey.showUrencriterium) private var show = true
    @AppStorage(SettingsKey.urencriteriumTarget) private var target = SettingsKey.defaultTarget
    @AppStorage(SettingsKey.menuBarStyle) private var menuBarStyle = MenuBarStyle.both.rawValue
    @AppStorage(SettingsKey.animations) private var animations = true
    @AppStorage(SettingsKey.showMenuSummary) private var showMenuSummary = true
    @AppStorage(SettingsKey.askNoteOnStop) private var askNote = true
    @AppStorage(SettingsKey.menuAnimation) private var menuAnimation = true
    @AppStorage(SettingsKey.autoBackupEnabled) private var autoBackup = true
    @AppStorage(SettingsKey.autoBackupPath) private var backupPath = SettingsKey.defaultBackupPath

    @AppStorage(SettingsKey.language) private var language = AppLanguage.en.rawValue
    @AppStorage(SettingsKey.projectsEnabled) private var projectsEnabled = false
    @AppStorage(SettingsKey.budgetAlerts) private var budgetAlerts = true
    @State private var notificationStatus = ""
    @State private var showReset = false
    @AppStorage(ReminderSettings.enabledKey) private var remind = false
    @AppStorage(ReminderSettings.firstKey) private var remindFirst = ReminderSettings.defaultFirst
    @AppStorage(ReminderSettings.everyKey) private var remindEvery = ReminderSettings.defaultEvery

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

            Section("Projecten") {
                Toggle("Projecten gebruiken", isOn: $projectsEnabled)
                Text("Werk per klant met projecten: vaste prijs of uurtarief, geschatte uren en effectief tarief per project. Uit = tikk. werkt zoals voorheen. Je projecten blijven bewaard.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Waarschuw bij 80% en 100% van de geschatte uren", isOn: $budgetAlerts)
                    .disabled(!projectsEnabled)
                    .onChange(of: budgetAlerts) { if budgetAlerts { NotificationService.shared.requestPermission() } }
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
                Button("Back-up terugzetten…") { model.restoreBackup() }
                if let m = model.statusMessage { Text(m).font(.caption).foregroundStyle(.secondary) }
            }

            Section("Algemeen") {
                Picker("Taal", selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .onChange(of: language) {
                    if let l = AppLanguage(rawValue: language) { L10n.persist(l) }
                    NotificationService.shared.setUp()
                    notificationStatus = ""
                    Task { notificationStatus = await NotificationService.shared.statusText() }
                }
                Text("Sommige systeemvensters (zoals bestandskiezers) volgen na een herstart.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Toon totalen en urencriterium in het menu", isOn: $showMenuSummary)
                Picker("Menubalk toont", selection: $menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Animaties in het menu (hover en doorrollende timer)", isOn: $animations)
                Toggle("Vraag om een notitie bij stoppen", isOn: $askNote)
                Toggle("Start bij inloggen", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
                Toggle("Animatie in de menubalk terwijl de timer loopt", isOn: $menuAnimation)
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    Text("Verminder beweging staat aan in macOS, dus Tikk blijft stil.").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                HStack(spacing: 12) {
                    TikkFigure(pose: .master, scale: 3)
                    VStack(alignment: .leading, spacing: 4) {
                        Wordmark(scale: 1.5)
                        Text("Your tiny timekeeper. Versie \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Reset") {
                Text("Zet de hele app terug naar het begin: alle gegevens en instellingen worden gewist.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Reset app naar fabrieksinstellingen…", role: .destructive) { showReset = true }
                if let e = model.errorMessage { Text(e).font(.caption).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 12)
        .sheet(isPresented: $showReset) { ResetAppSheet(model: model) { showReset = false } }
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
        panel.prompt = tr("Kies")
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { setPath(url.path) }
    }
}
