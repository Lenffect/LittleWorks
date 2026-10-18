import SwiftUI

enum SettingsKey {
    static let showUrencriterium = "showUrencriterium"
    static let urencriteriumTarget = "urencriteriumTarget"
    static let defaultTarget = 1225.0
    static let autoBackupEnabled = "autoBackupEnabled"
    static let autoBackupPath = "autoBackupPath"
    #if os(macOS)
    static let defaultBackupPath = NSHomeDirectory() + "/Desktop/LittleWorks/Backups"
    #else
    static let defaultBackupPath = NSHomeDirectory() + "/Documents/Backups"
    #endif
    static let menuBarStyle = "menuBarStyle"
    static let animations = "animationsEnabled"
    static let showMenuSummary = "showMenuSummary"
    static let askNoteOnStop = "askNoteOnStop"
    static let reportShowIncome = "reportShowIncome"
    static let menuAnimation = "menuAnimation"
    static let onboardingDone = "onboardingDone"
    static let language = "appLanguage"
    static let projectsEnabled = "projectsEnabled"
    static let budgetAlerts = "projectBudgetAlerts"
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

enum BudgetAlertSetting {
    static var isEnabled: Bool { UserDefaults.standard.object(forKey: SettingsKey.budgetAlerts) as? Bool ?? true }
}

enum ProjectsSetting {
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.projectsEnabled) }
}

enum NoteSetting {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.askNoteOnStop) as? Bool ?? true
    }
}
