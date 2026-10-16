import Foundation
import UserNotifications

enum ReminderSettings {
    static let enabledKey = "remindEnabled"
    static let firstKey = "remindFirstMinutes"
    static let everyKey = "remindEveryMinutes"
    static let defaultFirst = 60
    static let defaultEvery = 30

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false }
    static var first: TimeInterval { TimeInterval(max(1, UserDefaults.standard.object(forKey: firstKey) as? Int ?? defaultFirst)) * 60 }
    static var every: TimeInterval { TimeInterval(max(1, UserDefaults.standard.object(forKey: everyKey) as? Int ?? defaultEvery)) * 60 }
}

/// Posts "still working on X?" notifications with Continue / Stop actions.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationService()
    private static let category = "REMINDER"

    /// Called on the main actor with the entry id when the user taps "Stop timer".
    var onStop: (@MainActor (UUID) -> Void)?

    func setUp() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let actions = [
            UNNotificationAction(identifier: "continue", title: "Ja, ik werk door"),
            UNNotificationAction(identifier: "stop", title: "Stop timer", options: []),
        ]
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: actions, intentIdentifiers: [])
        ])
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func statusText() async -> String {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: "Meldingen staan aan."
        case .denied: "Meldingen staan uit voor tikk. Zet ze aan in Systeeminstellingen → Meldingen."
        default: "Nog geen toestemming voor meldingen."
        }
    }

    func send(clientName: String, elapsed: TimeInterval, entryId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = "Werk je nog aan \(clientName)?"
        content.body = "De timer loopt al \(Format.short(elapsed)) uur."
        content.sound = .default
        content.categoryIdentifier = Self.category
        content.userInfo = ["entryId": entryId.uuidString]
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "tikk-reminder", content: content, trigger: nil))
    }

    // Show banners even though tikk is the active app.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == "stop",
              let raw = response.notification.request.content.userInfo["entryId"] as? String,
              let id = UUID(uuidString: raw) else { return }
        await MainActor.run { onStop?(id) }
    }
}
