import AppKit
import Foundation
import Observation
import ServiceManagement
import SwiftData
import LittleWorksCore

@MainActor
@Observable
final class AppModel {
    /// Minutes away before we ask what to do with the time.
    static let awayThreshold: TimeInterval = 5 * 60
    private static let lastSeenKey = "lastSeenAt"

    let container: ModelContainer
    private let context: ModelContext
    private let engine: TimerEngine
    private let store: SwiftDataEntryStore

    private(set) var clients: [Client] = []
    private(set) var active: TimeEntry?
    private(set) var now = Date()
    private(set) var todayByClient: [UUID: TimeInterval] = [:]
    private(set) var yearTotal: TimeInterval = 0
    private(set) var weekByClient: [UUID: TimeInterval] = [:]
    var errorMessage: String?
    var statusMessage: String?
    /// Bumped each time the main window is freshly opened, so it starts on the overview page.
    private(set) var mainWindowOpenCount = 0
    func mainWindowWillOpen() { mainWindowOpenCount += 1 }
    /// Result of the last automatic backup (shown in settings).
    private(set) var autoBackupStatus: String?
    /// Bumped on every reload, so screens can refresh when data changed.
    private(set) var dataVersion = 0

    /// Drives the menu-bar icon (idle / tracking animation).
    let menuIcon = MenuBarIcon()
    /// When the timer was last stopped by the user (shows Tikk's "klaar" pose for a few seconds).
    private(set) var lastStopped: Date?

    private var sleepStartedAt: Date?
    private var ticker: Timer?

    init() {
        do {
            container = try ModelContainer(
                for: ClientRecord.self, EntryRecord.self,
                configurations: ModelConfiguration("Tikk"))
        } catch {
            fatalError("Kan database niet openen: \(error)")
        }
        context = container.mainContext
        store = SwiftDataEntryStore(context: context)
        engine = TimerEngine(store: store)
        reload()
        let awaySince = pendingCrashRecovery()
        autoBackup()
        observeSleep()
        NotificationService.shared.setUp()
        NotificationService.shared.onStop = { [weak self] id in
            if self?.active?.id == id { self?.stop() }
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Ask after launch has finished, otherwise the alert can end up hidden or block startup.
        if let awaySince {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                MainActor.assumeIsolated { self?.askAway(since: awaySince, reason: "tikk. was niet actief") }
            }
        }
    }

    // MARK: - Derived

    var activeClient: Client? { active.flatMap { a in clients.first { $0.id == a.clientId } } }
    var activeElapsed: TimeInterval { active?.duration(at: now) ?? 0 }
    var todayTotal: TimeInterval { todayByClient.values.reduce(0, +) }
    var weekTotal: TimeInterval { weekByClient.values.reduce(0, +) }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch { errorMessage = "Opstarten bij inloggen mislukt: \(error.localizedDescription)" }
        }
    }

    // MARK: - Actions

    /// Entry that just stopped and is waiting for a note (nil when nothing to ask).
    private(set) var notePromptEntryId: UUID?

    func toggle(_ client: Client) {
        let previous = active?.id
        perform { try engine.toggle(clientId: client.id) }
        if previous != nil, active == nil { lastStopped = Date() }
        promptForNote(ifStopped: previous)
    }

    func stop() {
        let previous = active?.id
        perform { try engine.stop() }
        if previous != nil { lastStopped = Date() }
        promptForNote(ifStopped: previous)
    }

    private func promptForNote(ifStopped id: UUID?) {
        guard let id, NoteSetting.isEnabled, entry(id: id)?.endTime != nil else { return }
        notePromptEntryId = id
    }

    func dismissNotePrompt() { notePromptEntryId = nil }

    func saveNote(_ text: String, for id: UUID) {
        defer { notePromptEntryId = nil }
        guard var e = entry(id: id) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        e.note = trimmed.isEmpty ? nil : trimmed
        updateEntry(e)
    }

    /// Adds a client. Returns false (and sets errorMessage) when the name is empty or already taken
    /// (case-insensitive, archived clients included).
    @discardableResult
    func addClient(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        if let existing = allClients.first(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            errorMessage = existing.isArchived
                ? "\"\(existing.name)\" bestaat al als gearchiveerde klant. Herstel die onder Klanten."
                : "Er is al een klant met de naam \"\(existing.name)\"."
            return false
        }
        errorMessage = nil
        context.insert(ClientRecord(Client(name: trimmed)))
        perform {}
        return true
    }

    func archive(_ client: Client) {
        if let r = try? context.fetch(FetchDescriptor<ClientRecord>(predicate: #Predicate { $0.id == client.id })).first {
            if active?.clientId == client.id { stop() }
            r.isArchived = true
            perform {}
        }
    }

    /// All entries grouped per calendar day (split at midnight), newest day first.
    func overviewDays() -> [DayGroup] {
        let cal = Calendar.current
        let now = Date()
        let names = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<ClientRecord>())) ?? []).map { ($0.id, $0.name) })
        let entries = (try? store.entries(in: DateInterval(start: .distantPast, end: .distantFuture))) ?? []
        var byDay: [Date: [DayRow]] = [:]
        for entry in entries {
            for seg in Totals.segments(of: entry, now: now, calendar: cal) {
                byDay[seg.day, default: []].append(DayRow(
                    entryId: entry.id, clientName: names[entry.clientId] ?? "Onbekend", note: entry.note,
                    start: seg.start, end: seg.end, isRunning: entry.isActive && seg.end == now))
            }
        }
        return byDay.keys.sorted(by: >).map { day in
            DayGroup(day: day, rows: byDay[day]!.sorted { $0.start > $1.start })
        }
    }

    /// Clients to choose from when editing an entry (archived ones included).
    var allClients: [Client] {
        ((try? context.fetch(FetchDescriptor<ClientRecord>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []).map(\.value)
    }

    func entry(id: UUID) -> TimeEntry? {
        (try? context.fetch(FetchDescriptor<EntryRecord>(predicate: #Predicate { $0.id == id })))?.first?.value
    }

    /// Returns false (and sets errorMessage) when the edit is invalid.
    @discardableResult
    func updateEntry(_ entry: TimeEntry) -> Bool {
        do { try engine.update(entry) } catch TimerError.endBeforeStart {
            errorMessage = "Het eind ligt vóór de start."
            return false
        } catch { errorMessage = error.localizedDescription; return false }
        reload()
        autoBackup()
        return true
    }

    func deleteEntry(id: UUID) { perform { try store.deleteEntry(id: id) } }

    func exportBackup() {
        do {
            if let url = try Backup.export(from: context) { statusMessage = "Back-up opgeslagen: \(url.lastPathComponent)" }
        } catch { errorMessage = "Back-up mislukt: \(error.localizedDescription)" }
    }

    /// Lets the user pick a JSON backup and replaces all current data with it, after confirmation.
    /// The current data is saved to a separate file first, so the restore itself can be undone.
    func restoreBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.message = "Kies een tikk.-back-up (JSON)"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let file = try Backup.read(from: url)
            let current = try Backup.snapshot(from: context)

            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Back-up terugzetten?"
            alert.informativeText = """
            Back-up van \(file.exportedAt.formatted(date: .long, time: .shortened)): \(file.clients.count) klanten, \(file.entries.count) registraties.

            Je huidige gegevens (\(current.clients.count) klanten, \(current.entries.count) registraties) worden hiermee vervangen. \
            Ze worden eerst bewaard in een bestand in je back-upmap.
            """
            alert.addButton(withTitle: "Vervangen")
            alert.addButton(withTitle: "Annuleer")
            guard alert.runModal() == .alertFirstButtonReturn else { return }

            let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)
                .timeSeparator(.omitted).dateSeparator(.omitted))
            let safety = AutoBackup.folder.appendingPathComponent("tikk-voor-terugzetten-\(stamp).json")
            try FileManager.default.createDirectory(at: AutoBackup.folder, withIntermediateDirectories: true)
            try Backup.data(for: current, format: .json).write(to: safety, options: .atomic)

            try Backup.replaceAll(in: context, with: file)
            reload()
            autoBackup()
            statusMessage = "Back-up teruggezet. Je vorige gegevens staan in \(safety.lastPathComponent)."
        } catch {
            errorMessage = "Terugzetten mislukt: \(error.localizedDescription)"
            reload()
        }
    }

    /// Writes the rolling backup file when enabled. Never throws; failures show up in settings.
    func autoBackup() {
        guard AutoBackup.isEnabled else { autoBackupStatus = "Automatische back-up staat uit."; return }
        do {
            let url = try AutoBackup.write(try Backup.snapshot(from: context))
            autoBackupStatus = "Laatste back-up \(Date().formatted(date: .omitted, time: .standard)) → \(url.path)"
        } catch {
            autoBackupStatus = "Automatische back-up mislukt: \(error.localizedDescription)"
        }
    }

    // MARK: - Archived clients, rates, report

    var archivedClients: [Client] { allClients.filter(\.isArchived) }

    func unarchive(_ client: Client) {
        if let r = try? context.fetch(FetchDescriptor<ClientRecord>(predicate: #Predicate { $0.id == client.id })).first {
            r.isArchived = false
            perform {}
        }
    }

    /// Number of registrations and total seconds that belong to a client.
    func usage(of clientId: UUID) -> (count: Int, seconds: TimeInterval) {
        let all = (try? context.fetch(FetchDescriptor<EntryRecord>(predicate: #Predicate { $0.clientId == clientId }))) ?? []
        return (all.count, all.reduce(0) { $0 + $1.value.duration(at: Date()) })
    }

    /// Irreversibly deletes an archived client together with all its registrations.
    func deleteClientPermanently(_ client: Client) {
        guard client.isArchived else { return }
        let id = client.id
        perform {
            for e in try context.fetch(FetchDescriptor<EntryRecord>(predicate: #Predicate { $0.clientId == id })) {
                context.delete(e)
            }
            for c in try context.fetch(FetchDescriptor<ClientRecord>(predicate: #Predicate { $0.id == id })) {
                context.delete(c)
            }
        }
    }

    func setRate(_ rate: Decimal?, for clientId: UUID) {
        if let r = try? context.fetch(FetchDescriptor<ClientRecord>(predicate: #Predicate { $0.id == clientId })).first {
            r.hourlyRate = rate
            perform {}
        }
    }

    func setMonthlyFee(_ fee: Decimal?, for clientId: UUID) {
        if let r = try? context.fetch(FetchDescriptor<ClientRecord>(predicate: #Predicate { $0.id == clientId })).first {
            r.monthlyFee = fee
            perform {}
        }
    }

    /// Seconds per client in the current calendar month.
    func monthSeconds() -> [UUID: TimeInterval] {
        guard let month = Calendar.current.dateInterval(of: .month, for: now) else { return [:] }
        let e = (try? store.entries(in: month)) ?? []
        return Totals.secondsPerClient(entries: e, in: month, now: now)
    }

    /// Hours per client in `interval` (archived clients included). Empty `clientIds` means all clients.
    func report(in interval: DateInterval, clientIds: Set<UUID> = []) -> [ReportRow] {
        let entries = (try? store.entries(in: interval)) ?? []
        let seconds = Totals.secondsPerClient(entries: entries, in: interval, now: Date())
        return allClients
            .filter { clientIds.isEmpty || clientIds.contains($0.id) }
            .compactMap { c in
                guard let s = seconds[c.id], s > 0 else { return nil }
                return ReportRow(client: c, seconds: s)
            }
            .sorted { $0.seconds > $1.seconds }
    }

    /// Every registration in the period, clipped at the period edges, for the Excel export.
    func exportEntries(in interval: DateInterval, clientIds: Set<UUID> = []) -> [ExportEntry] {
        let now = Date()
        let clients = Dictionary(uniqueKeysWithValues: allClients.map { ($0.id, $0) })
        return ((try? store.entries(in: interval)) ?? []).compactMap { e in
            guard let client = clients[e.clientId], clientIds.isEmpty || clientIds.contains(e.clientId) else { return nil }
            let start = max(e.startTime, interval.start)
            let end = min(e.endTime ?? now, interval.end)
            guard end > start else { return nil }
            return ExportEntry(client: client, start: start, end: end, isRunning: e.isActive, note: e.note)
        }
    }

    func exportReport(interval: DateInterval, clientIds: Set<UUID>, includeIncome: Bool) {
        do {
            let url = try ReportExport.save(
                entries: exportEntries(in: interval, clientIds: clientIds),
                summary: report(in: interval, clientIds: clientIds),
                interval: interval, includeIncome: includeIncome)
            if let url { statusMessage = "Rapport opgeslagen: \(url.lastPathComponent)" }
        } catch { errorMessage = "Export mislukt: \(error.localizedDescription)" }
    }

    private func perform(_ work: () throws -> Void) {
        do { try work(); try context.save() } catch { errorMessage = error.localizedDescription }
        reload()
        autoBackup()
    }

    // MARK: - Data

    private func reload() {
        dataVersion += 1
        now = Date()
        let cal = Calendar.current
        clients = ((try? context.fetch(FetchDescriptor<ClientRecord>(sortBy: [SortDescriptor(\.createdAt)]))) ?? [])
            .filter { !$0.isArchived }.map(\.value)
        active = try? engine.activeEntry()
        menuIcon.sync(tracking: active != nil)

        let dayStart = cal.startOfDay(for: now)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let week = cal.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: dayStart, end: dayEnd)
        func totals(_ i: DateInterval) -> [UUID: TimeInterval] {
            let e = (try? store.entries(in: i)) ?? []
            return Totals.secondsPerClient(entries: e, in: i, now: now)
        }
        todayByClient = totals(DateInterval(start: dayStart, end: dayEnd))
        weekByClient = totals(week)
        if let year = cal.dateInterval(of: .year, for: now) {
            yearTotal = totals(year).values.reduce(0, +)
        }
    }

    private var nextReminderAt: Date?
    private var reminderEntryId: UUID?

    /// "Still working on X?" reminder: first after N minutes of a running timer, then every M minutes.
    private func checkReminder() {
        guard ReminderSettings.isEnabled, let entry = active, let client = activeClient else {
            nextReminderAt = nil; reminderEntryId = nil; return
        }
        if reminderEntryId != entry.id {
            reminderEntryId = entry.id
            var next = entry.startTime.addingTimeInterval(ReminderSettings.first)
            while next <= now { next = next.addingTimeInterval(ReminderSettings.every) }
            nextReminderAt = next
        }
        if let due = nextReminderAt, now >= due {
            NotificationService.shared.send(clientName: client.name, elapsed: entry.duration(at: now), entryId: entry.id)
            nextReminderAt = now.addingTimeInterval(ReminderSettings.every)
        }
    }

    func sendTestReminder() {
        NotificationService.shared.send(
            clientName: activeClient?.name ?? "een klant", elapsed: activeElapsed, entryId: active?.id ?? UUID())
    }

    private func tick() {
        MenuBarFont.apply()
        now = Date()
        menuIcon.sync(tracking: active != nil)
        checkReminder()
        if active != nil {
            UserDefaults.standard.set(now, forKey: Self.lastSeenKey)
            if Int(now.timeIntervalSince1970) % 60 == 0 { reload() }
        }
    }

    // MARK: - Crash recovery & sleep

    /// If a timer was running when tikk. last ran more than 5 minutes ago, returns when we lost track.
    private func pendingCrashRecovery() -> Date? {
        guard let running = active,
              let lastSeen = UserDefaults.standard.object(forKey: Self.lastSeenKey) as? Date,
              Date().timeIntervalSince(lastSeen) > Self.awayThreshold else { return nil }
        return max(lastSeen, running.startTime)
    }

    private func observeSleep() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleepStartedAt = Date() }
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let slept = self.sleepStartedAt else { return }
                self.sleepStartedAt = nil
                if self.active != nil, Date().timeIntervalSince(slept) > Self.awayThreshold {
                    self.askAway(since: slept, reason: "Je Mac sliep")
                }
            }
        }
    }

    /// Ask what to do with the time since `since` while a timer was running.
    private func askAway(since: Date, reason: String) {
        let minutes = Int(Date().timeIntervalSince(since) / 60)
        let alert = NSAlert()
        alert.messageText = "\(reason) \(Format.duration(Date().timeIntervalSince(since))) (\(minutes) min)"
        alert.icon = NSImage.tikk(reason.contains("sliep") ? .slaap : .oeps)
        alert.informativeText = "De timer liep door. Wat doen we met die tijd?"
        alert.addButton(withTitle: "Stop op het moment van weggaan")
        alert.addButton(withTitle: "Tijd behouden")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            perform { try engine.stop(at: since) }
        }
    }
}

enum Format {
    static func duration(_ s: TimeInterval) -> String {
        let t = Int(s)
        return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
    }
    static func short(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        return String(format: "%d:%02d", m / 60, m % 60)
    }
}

struct ReportRow: Identifiable {
    let client: Client
    let seconds: TimeInterval
    var id: UUID { client.id }
    var hours: Double { seconds / 3600 }
    var income: Decimal? { client.hourlyRate.map { $0 * Decimal(hours) } }
}
