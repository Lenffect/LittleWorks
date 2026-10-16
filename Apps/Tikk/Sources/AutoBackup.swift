import Foundation

/// Rolling local backup, rewritten after every change (start, stop, edit, ...).
/// The folder is configurable, so it can point into iCloud Drive.
enum AutoBackup {
    static let fileName = "tikk-autobackup.json"

    static var folder: URL {
        let path = UserDefaults.standard.string(forKey: SettingsKey.autoBackupPath) ?? SettingsKey.defaultBackupPath
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.autoBackupEnabled) as? Bool ?? true
    }

    static func write(_ file: BackupFile) throws -> URL {
        let dir = folder
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)
        try Backup.data(for: file, format: .json).write(to: url, options: .atomic)
        return url
    }
}
