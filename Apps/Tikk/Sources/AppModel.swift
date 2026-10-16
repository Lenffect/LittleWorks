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
    /// Result of the last automatic backup (shown in settings).
    private(set) var autoBackupStatus: String?
    /// Bumped on every reload, so screens can refresh when data changed.
    private(set) var dataVersion = 0

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
        recoverAfterCrash()
        autoBackup()
        observeSleep()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
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
        promptForNote(ifStopped: previous)
    }

    func stop() {
        let previous = active?.id
        perform { try engine.stop() }
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

    func addClient(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        context.insert(ClientRecord(Client(name: trimmed)))
        perform {}
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

    private func tick() {
        now = Date()
        if active != nil {
            UserDefaults.standard.set(now, forKey: Self.lastSeenKey)
            if Int(now.timeIntervalSince1970) % 60 == 0 { reload() }
        }
    }

    // MARK: - Crash recovery & sleep

    private func recoverAfterCrash() {
        guard let running = active,
              let lastSeen = UserDefaults.standard.object(forKey: Self.lastSeenKey) as? Date,
              Date().timeIntervalSince(lastSeen) > Self.awayThreshold else { return }
        askAway(since: max(lastSeen, running.startTime), reason: "tikk. was niet actief")
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
