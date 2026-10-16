import AppKit
import SwiftUI

/// Brand colors (Assets.xcassets): Tikk Orange is the accent, Warm Off-White / Soft Black the surface.
enum Brand {
    static let background = Color("BrandBackground")
    static let ink = Color("BrandInk")
    static let muted = Color("BrandMuted")
    static let green = Color("BrandGreen")
}

/// Tikk's poses (20×20 art pixels). Pixel art: always scaled in whole steps, without smoothing.
enum TikkPose: String {
    case master = "TikkMaster", leeg = "TikkLeeg", klaar = "TikkKlaar", oeps = "TikkOeps", slaap = "TikkSlaap"
    case werkA = "TikkWerkA", werkB = "TikkWerkB"
}

struct TikkFigure: View {
    let pose: TikkPose
    /// Points per art pixel. Use whole numbers so the pixels stay crisp.
    var scale: CGFloat = 3

    var body: some View {
        Image(pose.rawValue)
            .interpolation(.none)
            .resizable()
            .frame(width: 20 * scale, height: 20 * scale)
            .accessibilityHidden(true)
    }
}

/// The "tikk." wordmark (26×12 art pixels, orange full stop).
struct Wordmark: View {
    var scale: CGFloat = 1.5

    var body: some View {
        Image("WordmarkTikk")
            .interpolation(.none)
            .resizable()
            .frame(width: 26 * scale, height: 12 * scale)
            .accessibilityLabel("tikk.")
    }
}

extension NSImage {
    /// A Tikk pose as a crisp (non-smoothed) image, for places that need an NSImage such as alerts.
    static func tikk(_ pose: TikkPose, points: CGFloat = 64) -> NSImage? {
        guard let source = NSImage(named: pose.rawValue) else { return nil }
        let size = NSSize(width: points, height: points)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        source.draw(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
}
