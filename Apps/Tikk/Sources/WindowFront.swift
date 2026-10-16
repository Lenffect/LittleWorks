import AppKit
import SwiftUI

/// Opens a window scene and brings it in front of everything, also when it was already open behind.
@MainActor
func openInFront(_ id: String, title: String, using openWindow: OpenWindowAction) {
    openWindow(id: id)
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.async {
        if let w = NSApp.windows.first(where: { $0.title == title }) {
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
        }
    }
}

enum WindowTitle {
    static let settings = "tikk. instellingen"
    static let overview = "tikk. overzicht"
}
