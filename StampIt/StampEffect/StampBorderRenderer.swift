import Cocoa
import CoreGraphics

struct StampBorderRenderer {
    // SVG dimensions
    private static let svgWidth: CGFloat = 2351
    private static let svgHeight: CGFloat = 3352

    // Render at SVG's native resolution for crisp edges
    private static let minOutputWidth: Int = 2351

    /// Apply the SVG stamp shape as a mask — image fills the stamp, transparent outside.
    static func applyStampBorder(to image: CGImage) -> CGImage? {
        guard let stampTemplate = loadStampSVG() else { return nil }

        let w = max(image.width, minOutputWidth)
        let h = Int(CGFloat(w) * (svgHeight / svgWidth))
        let size = NSSize(width: w, height: h)
        let rect = NSRect(origin: .zero, size: size)

        // Create output bitmap
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = size

        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: bitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = ctx

        // 1. Draw captured image filling the entire area
        let capturedNSImage = NSImage(cgImage: image, size: NSSize(width: CGFloat(image.width), height: CGFloat(image.height)))
        capturedNSImage.draw(in: rect)

        // 2. Draw stamp template on top using .destinationIn
        //    This keeps only the image pixels where the stamp is opaque — transparent everywhere else
        stampTemplate.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        return bitmap.cgImage
    }

    private static func loadStampSVG() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "stamp-border", withExtension: "svg") else { return nil }
        return NSImage(contentsOf: url)
    }
}
