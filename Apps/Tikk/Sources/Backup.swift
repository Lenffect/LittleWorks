import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers
import LittleWorksCore

struct BackupFile: Codable {
    var version = 1
    var exportedAt: Date
    var clients: [Client]
    var entries: [TimeEntry]
}

enum BackupFormat: String, CaseIterable {
    case json, csv

    var title: String {
        switch self {
        case .json: "JSON (volledige back-up)"
        case .csv: "CSV (voor Excel)"
        }
    }
    var type: UTType { self == .json ? .json : .commaSeparatedText }
}

enum Backup {
    @MainActor
    static func snapshot(from context: ModelContext) throws -> BackupFile {
        let clients = try context.fetch(FetchDescriptor<ClientRecord>(sortBy: [SortDescriptor(\.createdAt)])).map(\.value)
        let entries = try context.fetch(FetchDescriptor<EntryRecord>(sortBy: [SortDescriptor(\.startTime)])).map(\.value)
        return BackupFile(exportedAt: Date(), clients: clients, entries: entries)
    }

    static func data(for file: BackupFile, format: BackupFormat) throws -> Data {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(file)
        case .csv:
            return Data(csv(for: file).utf8)
        }
    }

    /// Dutch Excel style: `;` as separator, decimal comma.
    private static func csv(for file: BackupFile) -> String {
        let names = Dictionary(uniqueKeysWithValues: file.clients.map { ($0.id, $0.name) })
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "nl_NL")
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }

        var lines = ["Klant;Start;Eind;Uren;Notitie"]
        for e in file.entries {
            let hours = String(format: "%.2f", e.duration(at: Date()) / 3600).replacingOccurrences(of: ".", with: ",")
            lines.append([
                q(names[e.clientId] ?? "Onbekend"),
                fmt.string(from: e.startTime),
                e.endTime.map { fmt.string(from: $0) } ?? "loopt",
                hours,
                q(e.note ?? ""),
            ].joined(separator: ";"))
        }
        return "\u{FEFF}" + lines.joined(separator: "\n") + "\n"
    }

    static func read(from url: URL) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: Data(contentsOf: url))
        guard file.version == 1 else {
            throw NSError(domain: "tikk", code: 2, userInfo: [NSLocalizedDescriptionKey: "Onbekende back-upversie \(file.version)"])
        }
        return file
    }

    /// Replaces ALL data with the contents of `file`. A timer that was still running in the
    /// backup is closed at the time the backup was made.
    @MainActor
    static func replaceAll(in context: ModelContext, with file: BackupFile) throws {
        for e in try context.fetch(FetchDescriptor<EntryRecord>()) { context.delete(e) }
        for c in try context.fetch(FetchDescriptor<ClientRecord>()) { context.delete(c) }
        try context.save()
        for c in file.clients { context.insert(ClientRecord(c)) }
        for var e in file.entries {
            if e.endTime == nil { e.endTime = max(e.startTime, file.exportedAt) }
            context.insert(EntryRecord(e))
        }
        try context.save()
    }

    /// Asks where to save and in which format, then writes the file.
    @MainActor
    static func export(from context: ModelContext) throws -> URL? {
        let file = try snapshot(from: context)

        let panel = NSSavePanel()
        let day = Date.now.formatted(.iso8601.year().month().day())
        let picker = FormatPicker(panel: panel, baseName: "tikk-backup-\(day)")
        panel.accessoryView = picker.view
        picker.apply()
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        try data(for: file, format: picker.selected).write(to: url, options: .atomic)
        return url
    }
}

/// Format popup inside the save panel.
@MainActor
private final class FormatPicker: NSObject {
    let view: NSView
    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let panel: NSSavePanel
    private let baseName: String

    var selected: BackupFormat { BackupFormat.allCases[max(0, popup.indexOfSelectedItem)] }

    init(panel: NSSavePanel, baseName: String) {
        self.panel = panel
        self.baseName = baseName
        popup.addItems(withTitles: BackupFormat.allCases.map(\.title))
        let label = NSTextField(labelWithString: "Formaat:")
        let stack = NSStackView(views: [label, popup])
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        view = stack
        super.init()
        popup.target = self
        popup.action = #selector(changed)
    }

    @objc private func changed() { apply() }

    func apply() {
        panel.allowedContentTypes = [selected.type]
        panel.nameFieldStringValue = "\(baseName).\(selected.rawValue)"
    }
}
