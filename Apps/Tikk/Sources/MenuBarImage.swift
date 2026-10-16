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
    static var current: MenuBarStyle {
        MenuBarStyle(rawValue: UserDefaults.standard.string(forKey: SettingsKey.menuBarStyle) ?? "") ?? .both
    }
}

/// Draws the menu bar item ourselves and sets it on the status item's button once a second.
/// SwiftUI's own label re-laid out on every tick, which made the clock wobble; a plain image with
/// equal-width digits stays put.
@MainActor
enum MenuBarItem {
    /// `running` is nil when no timer is active.
    static func update(running: (name: String, time: String)?) {
        guard let button = statusButton() else { return }
        let style = MenuBarStyle.current
        let image: NSImage
        switch (running, style) {
        case (nil, .timeOnly):
            image = render(symbol: nil, text: "tikk.")
        case (nil, _):
            image = render(symbol: "clock", text: nil)
        case (let r?, .iconOnly):
            _ = r
            image = render(symbol: "clock.fill", text: nil)
        case (let r?, .timeOnly):
            image = render(symbol: nil, text: "\(r.name) \(r.time)")
        case (let r?, .both):
            image = render(symbol: "clock.fill", text: "\(r.name) \(r.time)")
        }
        button.title = ""
        button.imagePosition = .imageOnly
        button.image = image
    }

    private static func statusButton() -> NSStatusBarButton? {
        func find(in v: NSView) -> NSStatusBarButton? {
            if let b = v as? NSStatusBarButton { return b }
            for s in v.subviews { if let b = find(in: s) { return b } }
            return nil
        }
        for w in NSApp.windows where String(describing: type(of: w)) == "NSStatusBarWindow" {
            if let c = w.contentView, let b = find(in: c) { return b }
        }
        return nil
    }

    private static func render(symbol: String?, text: String?) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let attributed = text.map { NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: NSColor.black]) }
        let textSize = attributed?.size() ?? .zero
        let sym = symbol.flatMap {
            NSImage(systemSymbolName: $0, accessibilityDescription: "tikk.")?
                .withSymbolConfiguration(.init(pointSize: 13, weight: .regular))
        }
        let symSize = sym?.size ?? .zero
        let gap: CGFloat = (sym != nil && attributed != nil) ? 5 : 0
        let width = ceil(symSize.width + gap + textSize.width)
        let height = ceil(max(symSize.height, textSize.height, 16))

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            var x: CGFloat = 0
            if let sym {
                sym.draw(in: NSRect(x: 0, y: (height - symSize.height) / 2, width: symSize.width, height: symSize.height))
                x = symSize.width + gap
            }
            attributed?.draw(at: NSPoint(x: x, y: (height - textSize.height) / 2))
            return true
        }
        image.isTemplate = true   // follows the light/dark menu bar
        return image
    }
}
