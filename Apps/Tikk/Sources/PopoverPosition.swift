import AppKit

/// Makes the menu popover movable (drag its background) and resizable (drag its edges),
/// and remembers where you put it. Without a saved spot it opens at the right side of the screen.
@MainActor
final class PopoverPosition {
    static let shared = PopoverPosition()
    static let minSize = NSSize(width: 520, height: 480)
    private static let key = "popoverFrame"
    private static let rightMargin: CGFloat = 160

    private var observers: [NSObjectProtocol] = []
    private var shownAt = Date.distantPast
    private var applying = false

    func start() {
        guard observers.isEmpty else { return }
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
            guard let w = note.object as? NSWindow, Self.isPopover(w) else { return }
            MainActor.assumeIsolated { PopoverPosition.shared.shown(w) }
        })
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let w = note.object as? NSWindow, Self.isPopover(w) else { return }
                MainActor.assumeIsolated { PopoverPosition.shared.changed(w) }
            })
        }
    }

    static func reset() { UserDefaults.standard.removeObject(forKey: key) }

    private static func isPopover(_ w: NSWindow) -> Bool {
        String(describing: type(of: w)).hasPrefix("MenuBarExtraWindow")
    }

    private func shown(_ w: NSWindow) {
        shownAt = Date()
        w.styleMask.insert(.resizable)
        w.isMovableByWindowBackground = true
        w.minSize = Self.minSize
        // SwiftUI places the popover itself a moment after it appears; place ours after that.
        for delay in [0.05, 0.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak w] in
                guard let w else { return }
                MainActor.assumeIsolated { PopoverPosition.shared.place(w) }
            }
        }
    }

    private func place(_ w: NSWindow) {
        guard let screen = w.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = w.frame
        if let saved = UserDefaults.standard.string(forKey: Self.key).map(NSRectFromString),
           saved.width >= Self.minSize.width, saved.height >= Self.minSize.height,
           visible.intersects(saved) {
            frame = saved
        } else {
            frame.origin.x = visible.maxX - Self.rightMargin - frame.width
        }
        guard frame != w.frame else { return }
        applying = true
        w.setFrame(frame, display: true)
        applying = false
    }

    private func changed(_ w: NSWindow) {
        // Ignore SwiftUI's own placement right after opening and our own placement.
        guard !applying, Date().timeIntervalSince(shownAt) > 0.5, w.frame.width >= Self.minSize.width else { return }
        UserDefaults.standard.set(NSStringFromRect(w.frame), forKey: Self.key)
    }
}
