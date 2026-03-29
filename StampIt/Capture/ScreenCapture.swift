import Cocoa
import CoreGraphics

struct ScreenCapture {
    /// Capture a screen region.
    /// `rect` is in AppKit coordinates (origin bottom-left).
    static func captureRect(_ rect: CGRect) -> CGImage? {
        guard let screen = NSScreen.main else { return nil }
        let screenHeight = screen.frame.height

        let quartzRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        return CGWindowListCreateImage(
            quartzRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
    }
}
