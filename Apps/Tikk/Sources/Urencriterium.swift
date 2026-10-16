import SwiftUI

enum SettingsKey {
    static let showUrencriterium = "showUrencriterium"
    static let urencriteriumTarget = "urencriteriumTarget"
    static let defaultTarget = 1225.0
    static let autoBackupEnabled = "autoBackupEnabled"
    static let autoBackupPath = "autoBackupPath"
    static let defaultBackupPath = NSHomeDirectory() + "/Desktop/LittleWorks/Backups"
    static let reportShowIncome = "reportShowIncome"
}

/// Progress of hours worked this calendar year towards the urencriterium.
struct UrencriteriumBar: View {
    let yearSeconds: TimeInterval
    @AppStorage(SettingsKey.showUrencriterium) private var show = true
    @AppStorage(SettingsKey.urencriteriumTarget) private var target = SettingsKey.defaultTarget

    var body: some View {
        if show && target > 0 {
            let targetSeconds = target * 3600
            let fraction = min(1, yearSeconds / targetSeconds)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Urencriterium")
                    Spacer()
                    Text("\(Int(fraction * 100))%").monospacedDigit()
                }
                ProgressView(value: fraction)
                Text("\(Format.short(yearSeconds)) van \(Int(target)) u · nog \(Format.short(max(0, targetSeconds - yearSeconds)))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }
}
