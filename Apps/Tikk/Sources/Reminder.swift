#if os(macOS)
import AppKit
#endif
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
            UNNotificationAction(identifier: "continue", title: tr("Ja, ik werk door")),
            UNNotificationAction(identifier: "stop", title: tr("Stop timer"), options: []),
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
        case .authorized, .provisional, .ephemeral: tr("Meldingen staan aan.")
        case .denied: tr("Meldingen staan uit voor tikk. Zet ze aan in Systeeminstellingen → Meldingen.")
        default: tr("Nog geen toestemming voor meldingen.")
        }
    }

    func send(clientName: String, elapsed: TimeInterval, entryId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = tr("Werk je nog aan %@?", clientName)
        content.body = tr("De timer loopt al %@ uur.", Format.short(elapsed))
        content.sound = .default
        content.categoryIdentifier = Self.category
        content.userInfo = ["entryId": entryId.uuidString]
        Self.attach(.master, to: content)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "tikk-reminder", content: content, trigger: nil))
    }

    /// Adds a Tikk pose as the notification image (the app icon alone can show up blank for unsigned builds).
    private static func attach(_ pose: TikkPose, to content: UNMutableNotificationContent) {
        #if os(macOS)
        let side = 256
        guard let source = NSImage(named: pose.rawValue),
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .none
        source.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tikk-\(UUID().uuidString).png")
        guard (try? png.write(to: url)) != nil,
              let attachment = try? UNNotificationAttachment(identifier: "pose", url: url) else { return }
        content.attachments = [attachment]
        #endif
    }

    #if os(iOS)
    /// Schedules a "still working?" reminder for a moment in the future.
    func schedule(id: String, at date: Date, clientName: String, elapsed: TimeInterval, entryId: UUID) {
        let content = UNMutableNotificationContent()
        content.title = tr("Werk je nog aan %@?", clientName)
        content.body = tr("De timer loopt al %@ uur.", Format.short(elapsed))
        content.sound = .default
        content.categoryIdentifier = Self.category
        content.userInfo = ["entryId": entryId.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Schedules a plain notification `seconds` from now (project budget warnings).
    func scheduleAlert(id: String, after seconds: TimeInterval, title: String, body: String, pose: TikkPose = .master) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
    #endif

    /// Plain notification without actions, for project budget warnings.
    func sendAlert(title: String, body: String, id: String, pose: TikkPose = .master) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        Self.attach(pose, to: content)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
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
