import AppKit

/// Moves the menu popover to the right side of the screen (160 points inside the right edge).
/// The tikk. icon sits well left of the screen edge, so the default spot is too far to the left.
@MainActor
final class PopoverPosition {
    static let shared = PopoverPosition()
    private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let w = note.object as? NSWindow, Self.isPopover(w) else { return }
                MainActor.assumeIsolated { Self.align(w) }
            })
        }
        // The popover window keeps its first responder between openings, which left the
        // "Nieuwe klant" field active. Start every opening without a focused field.
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { note in
            guard let w = note.object as? NSWindow, Self.isPopover(w) else { return }
            MainActor.assumeIsolated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak w] in w?.makeFirstResponder(nil) }
            }
        })
    }

    private static func isPopover(_ w: NSWindow) -> Bool {
        String(describing: type(of: w)).hasPrefix("MenuBarExtraWindow")
    }

    private static func align(_ popover: NSWindow) {
        guard let screen = popover.screen ?? NSScreen.main else { return }
        let width = popover.frame.width
        let right = screen.visibleFrame.maxX - 160
        let x = right - width
        guard abs(popover.frame.origin.x - x) > 1 else { return }
        popover.setFrameOrigin(NSPoint(x: x, y: popover.frame.origin.y))
    }
}
