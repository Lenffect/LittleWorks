import AppKit

/// Renders the running-timer text as a template image for the menu bar. Menu bar text labels
/// ignore `monospacedDigit`, so the clock shifted a little on every second; here every digit has
/// the same width, so the text stays put.
enum MenuBarImage {
    static func make(_ text: String) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.black])
        let size = attributed.size()
        let image = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)), flipped: false) { rect in
            attributed.draw(at: NSPoint(x: 0, y: (rect.height - size.height) / 2))
            return true
        }
        image.isTemplate = true   // follows the light/dark menu bar
        return image
    }
}
