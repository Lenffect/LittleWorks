import SwiftUI
import UniformTypeIdentifiers
import LittleWorksCore

struct SettingsScreen: View {
    let model: AppModel
    @AppStorage(SettingsKey.language) private var language = AppLanguage.en.rawValue
    @AppStorage(SettingsKey.showUrencriterium) private var showUrencriterium = true
    @AppStorage(SettingsKey.urencriteriumTarget) private var target = SettingsKey.defaultTarget
    @AppStorage(SettingsKey.askNoteOnStop) private var askNote = true
    @AppStorage(SettingsKey.projectsEnabled) private var projectsEnabled = false
    @AppStorage(SettingsKey.budgetAlerts) private var budgetAlerts = true
    @AppStorage(SettingsKey.autoBackupEnabled) private var autoBackup = true
    @AppStorage(ReminderSettings.enabledKey) private var remind = false
    @AppStorage(ReminderSettings.firstKey) private var remindFirst = ReminderSettings.defaultFirst
    @AppStorage(ReminderSettings.everyKey) private var remindEvery = ReminderSettings.defaultEvery
    @AppStorage(AwaySetting.enabledKey) private var awayEnabled = true
    @AppStorage(AwaySetting.minutesKey) private var awayMinutes = AwaySetting.defaultMinutes
    @State private var notificationStatus = ""
    @State private var importing = false
    @State private var shareURL: URL?
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Urencriterium") {
                    Toggle("Urencriterium tonen", isOn: $showUrencriterium)
                    HStack {
                        Text("Doel (uren per jaar)")
                        Spacer()
                        TextField("", value: $target, format: .number.grouping(.never))
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 90)
                    }
                    .disabled(!showUrencriterium)
                }

                Section("Projecten") {
                    Toggle("Projecten gebruiken", isOn: $projectsEnabled)
                    Text("Werk per klant met projecten: vaste prijs of uurtarief, geschatte uren en effectief tarief per project. Uit = tikk. werkt zoals voorheen. Je projecten blijven bewaard.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Waarschuw bij 80% en 100% van de geschatte uren", isOn: $budgetAlerts)
                        .disabled(!projectsEnabled)
                        .onChange(of: budgetAlerts) { if budgetAlerts { NotificationService.shared.requestPermission() } }
                }
                .onChange(of: projectsEnabled) { model.rescheduleNotifications() }
                .onChange(of: budgetAlerts) { model.rescheduleNotifications() }

                Section("Herinnering") {
                    Toggle("Vraag of ik nog werk aan de klant", isOn: $remind)
                        .onChange(of: remind) { if remind { NotificationService.shared.requestPermission() } }
                    Stepper("Eerste herinnering na \(remindFirst) min", value: $remindFirst, in: 1...480, step: 5)
                        .disabled(!remind)
                    Stepper("Daarna elke \(remindEvery) min", value: $remindEvery, in: 1...480, step: 5)
                        .disabled(!remind)
                    Button("Stuur testmelding") { model.sendTestReminder() }
                    Text(notificationStatus).font(.caption).foregroundStyle(.secondary)
                }
                .onChange(of: remind) { model.rescheduleNotifications() }
                .onChange(of: remindFirst) { model.rescheduleNotifications() }
                .onChange(of: remindEvery) { model.rescheduleNotifications() }
                .task { notificationStatus = await NotificationService.shared.statusText() }

                Section("Weggeweest") {
                    Toggle("Vraag wat te doen met de tijd na lang weggaan", isOn: $awayEnabled)
                    Stepper("Vraag na \(awayMinutes) min weg", value: $awayMinutes, in: 5...480, step: 5)
                        .disabled(!awayEnabled)
                    Text("Als de timer liep terwijl tikk. op de achtergrond stond. Zet dit uit als je je telefoon vaak weglegt terwijl je werkt.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Back-up") {
                    Toggle("Automatisch back-uppen bij elke wijziging", isOn: $autoBackup)
                        .onChange(of: autoBackup) { model.autoBackup() }
                    if let status = model.autoBackupStatus { Text(status).font(.caption).foregroundStyle(.secondary) }
                    if let shareURL { ShareLink("Back-up delen", item: shareURL) }
                    Button("Back-up terugzetten…") { importing = true }
                    if let s = model.statusMessage { Text(s).font(.caption).foregroundStyle(.secondary) }
                }

                Section("Algemeen") {
                    Picker("Taal", selection: $language) {
                        ForEach(AppLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .onChange(of: language) {
                        if let l = AppLanguage(rawValue: language) { L10n.persist(l) }
                        NotificationService.shared.setUp()
                        Task { notificationStatus = await NotificationService.shared.statusText() }
                    }
                    Toggle("Vraag om een notitie bij stoppen", isOn: $askNote)
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
            .navigationTitle("Instellingen")
            .onAppear { shareURL = model.backupFileForSharing() }
            .onChange(of: model.dataVersion) { shareURL = model.backupFileForSharing() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                if case let .success(url) = result { model.restoreBackup(from: url) }
            }
            .sheet(isPresented: $showReset) { ResetSheet(model: model) { showReset = false } }
        }
    }
}

/// Typed confirmation before the whole app is reset to factory settings.
private struct ResetSheet: View {
    let model: AppModel
    let onDone: () -> Void
    @State private var typed = ""
    @State private var saveBackup = true

    private var phrase: String { tr("ik weet zeker dat ik de hele app wil resetten en alle gegevens wil verwijderen") }
    private var matches: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines).compare(phrase, options: [.caseInsensitive]) == .orderedSame
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Dit verwijdert **definitief** alle klanten, projecten en registraties, en al je instellingen (taal, herinneringen, back-upmap, urencriterium, enzovoort). tikk. start daarna opnieuw op alsof het net is geïnstalleerd, met de introductie. De automatische back-up wordt ook overschreven met de lege situatie. Dit kan niet ongedaan worden gemaakt.")
                        .foregroundStyle(.secondary)
                    Toggle("Bewaar eerst een laatste back-up in de back-upmap", isOn: $saveBackup)
                }
                Section("Typ de volgende zin om te bevestigen:") {
                    Text(phrase).font(.callout.weight(.semibold))
                    TextField("", text: $typed, axis: .vertical).autocorrectionDisabled().textInputAutocapitalization(.never)
                }
                Section {
                    Button("Alles verwijderen en resetten", role: .destructive) {
                        model.factoryReset(saveBackupFirst: saveBackup); onDone()
                    }
                    .disabled(!matches)
                }
            }
            .navigationTitle("Hele app resetten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annuleer", action: onDone) } }
        }
    }
}
