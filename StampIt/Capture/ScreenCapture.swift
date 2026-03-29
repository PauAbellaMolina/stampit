import Cocoa
import ScreenCaptureKit

struct ScreenCapture {
    /// Capture a screen region. Tries ScreenCaptureKit first, falls back to CGWindowListCreateImage.
    /// `rect` is in AppKit coordinates (origin bottom-left).
    static func captureRect(_ rect: CGRect) async -> CGImage? {
        guard let screen = NSScreen.main else { return nil }
        let scaleFactor = screen.backingScaleFactor
        let screenHeight = screen.frame.height

        // Flip Y from AppKit (bottom-left) to Quartz (top-left)
        let sourceRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        // Try ScreenCaptureKit first
        if let image = await captureWithSCK(sourceRect: sourceRect, size: rect.size, scaleFactor: scaleFactor) {
            return image
        }

        // Fallback to CGWindowListCreateImage
        return CGWindowListCreateImage(
            sourceRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        )
    }

    private static func captureWithSCK(sourceRect: CGRect, size: CGSize, scaleFactor: CGFloat) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return nil }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.sourceRect = sourceRect
            config.width = Int(size.width * scaleFactor)
            config.height = Int(size.height * scaleFactor)
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            return nil
        }
    }
}
