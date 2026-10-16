import AppKit

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case both, iconOnly, timeOnly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .both: "Icoon en tijd"
        case .iconOnly: "Alleen icoon"
        case .timeOnly: "Alleen tijd"
        }
    }
}

/// The menu bar ignores SwiftUI's `monospacedDigit()`, so the proportional digits made the item
/// a few points wider or narrower every second and the clock wobbled. Setting the font on the
/// status item's button itself gives every digit the same width.
@MainActor
enum MenuBarFont {
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    static func apply() {
        for w in NSApp.windows where String(describing: type(of: w)) == "NSStatusBarWindow" {
            if let content = w.contentView, let button = button(in: content), button.font != font {
                button.font = font
            }
        }
    }

    private static func button(in view: NSView) -> NSStatusBarButton? {
        if let b = view as? NSStatusBarButton { return b }
        for sub in view.subviews { if let b = button(in: sub) { return b } }
        return nil
    }
}
