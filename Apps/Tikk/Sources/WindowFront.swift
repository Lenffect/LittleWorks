import AppKit
import SwiftUI

enum WindowTitle { static let main = "tikk." }

/// Opens the main window in front of everything. The menu popover (a high-level window) is closed first.
/// A menu-bar-only app cannot take focus, so tikk. is a regular app (Dock icon) while a window is open.
@MainActor
func openMainWindow(model: AppModel, using openWindow: OpenWindowAction) {
    let alreadyOpen = NSApp.windows.contains {
        $0.isVisible && $0.title != "" && $0.styleMask.contains(.titled)
    }
    if !alreadyOpen { model.mainWindowWillOpen() }
    for w in NSApp.windows where String(describing: type(of: w)).hasPrefix("MenuBarExtraWindow") {
        w.orderOut(nil)
    }
    NSApp.setActivationPolicy(.regular)
    openWindow(id: "main")
    NSApp.activate()
    WindowWatcher.shared.start()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NSApp.activate()
        if let w = NSApp.windows.first(where: { $0.title == WindowTitle.main && $0.styleMask.contains(.titled) }) {
            w.makeKeyAndOrderFront(nil)
        }
    }
}

/// Back to menu-bar-only (no Dock icon) when the last window is closed.
@MainActor
final class WindowWatcher {
    static let shared = WindowWatcher()
    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                DispatchQueue.main.async {
                    let open = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
                    if !open { NSApp.setActivationPolicy(.accessory) }
                }
            }
        }
    }
}
