import AppKit
import Observation

/// The menu-bar icon: sleeping Tikk when idle, a 5-frame loop while a timer runs.
/// The animation only runs while tracking, and stays still when Reduce Motion is on or the user turned it off.
@MainActor
@Observable
final class MenuBarIcon {
    private(set) var name = "MenuIdle"

    @ObservationIgnored private var mode = Mode.idle
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var index = 0

    private enum Mode { case idle, still, animating }

    /// Frame names (template images, 20×20 pt) and how long each stays visible.
    private static let frames: [(name: String, seconds: TimeInterval)] = [
        ("MenuTracking1", 0.5), ("MenuTracking2", 0.5), ("MenuTracking3", 0.5),
        ("MenuTracking4", 0.08), ("MenuTracking5", 0.12),
    ]

    static var animationAllowed: Bool {
        (UserDefaults.standard.object(forKey: SettingsKey.menuAnimation) as? Bool ?? true)
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Cheap and idempotent: call it whenever the tracking state may have changed (also from the 1-second tick,
    /// so a change in Reduce Motion or the setting is picked up).
    func sync(tracking: Bool) {
        let wanted: Mode = !tracking ? .idle : (Self.animationAllowed ? .animating : .still)
        guard wanted != mode else { return }
        mode = wanted
        timer?.invalidate()
        timer = nil
        switch wanted {
        case .idle: name = "MenuIdle"
        case .still: name = Self.frames[0].name
        case .animating:
            index = 0
            showCurrentFrame()
        }
    }

    private func showCurrentFrame() {
        name = Self.frames[index].name
        let next = Timer(timeInterval: Self.frames[index].seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.mode == .animating else { return }
                self.index = (self.index + 1) % Self.frames.count
                self.showCurrentFrame()
            }
        }
        RunLoop.main.add(next, forMode: .common)   // keeps running while a menu or the popover is open
        timer = next
    }
}
