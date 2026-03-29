import Cocoa

protocol OverlayViewDelegate: AnyObject {
    func overlayViewDidClick(stampRect: NSRect)
    func overlayViewDidCancel()
}

class OverlayView: NSView {
    weak var delegate: OverlayViewDelegate?

    // Stamper image dimensions (points — PNG is 1536x2816px, display at half for Retina)
    private let stamperSize = NSSize(width: 256, height: 469)

    // Capture window within the stamper (top-left origin, in points)
    // Adjust these values to align the red rect with the stamp cutout
    private let windowInSVG = NSRect(x: 81, y: 170, width: 94, height: 129)
    private let windowCornerRadius: CGFloat = 4

    // Window center in stamper coordinates (top-left origin)
    private var windowCenterInSVG: NSPoint {
        NSPoint(x: windowInSVG.midX, y: windowInSVG.midY)
    }

    private var mouseLocation: NSPoint = .zero
    private var trackingArea: NSTrackingArea?
    private var stamperImage: NSImage?

    // Pinch-to-resize
    private var userScale: CGFloat = 1.0
    private let minUserScale: CGFloat = 0.4
    private let maxUserScale: CGFloat = 3.0

    // Press animation
    private var stamperScale: CGFloat = 1.0
    private var stamperOpacity: CGFloat = 1.0
    private var animationTimer: Timer?
    private var isAnimatingPress = false
    private let pressAnimationDuration: TimeInterval = 0.25
    private let pressMinScale: CGFloat = 0.85
    private let fadeOutDuration: TimeInterval = 0.15

    override init(frame: NSRect) {
        super.init(frame: frame)
        loadStamperImage()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadStamperImage()
    }

    private func loadStamperImage() {
        guard let url = Bundle.main.url(forResource: "stamper", withExtension: "png") else { return }
        stamperImage = NSImage(contentsOf: url)
    }

    override var acceptsFirstResponder: Bool { true }
    override var acceptsTouchEvents: Bool { get { true } set {} }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = window else { return }
        let windowPoint = window.mouseLocationOutsideOfEventStream
        mouseLocation = convert(windowPoint, from: nil)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    /// Scaled stamper size based on pinch gesture.
    private var scaledStamperSize: NSSize {
        NSSize(width: stamperSize.width * userScale, height: stamperSize.height * userScale)
    }

    /// The stamper drawing rect in view coordinates (AppKit: bottom-left origin).
    /// Positioned so the capture window is centered on the mouse.
    private var stamperRect: NSRect {
        let size = scaledStamperSize
        let scaledCenterX = windowCenterInSVG.x * userScale
        let scaledCenterY = windowCenterInSVG.y * userScale
        let offsetX = mouseLocation.x - scaledCenterX
        let offsetY = mouseLocation.y - (size.height - scaledCenterY)
        return NSRect(origin: NSPoint(x: offsetX, y: offsetY), size: size)
    }

    /// The capture window rect in view coordinates.
    var stampRect: NSRect {
        let sr = stamperRect
        let scaledWindowY = scaledStamperSize.height - windowInSVG.origin.y * userScale - windowInSVG.height * userScale
        return NSRect(
            x: sr.origin.x + windowInSVG.origin.x * userScale,
            y: sr.origin.y + scaledWindowY,
            width: windowInSVG.width * userScale,
            height: windowInSVG.height * userScale
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = stamperRect

        // Apply scale transform around stamper center for press animation
        if stamperScale != 1.0 {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            let cx = rect.midX
            let cy = rect.midY
            transform.translateX(by: cx, yBy: cy)
            transform.scaleX(by: stamperScale, yBy: stamperScale)
            transform.translateX(by: -cx, yBy: -cy)
            transform.concat()
        }

        stamperImage?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: stamperOpacity)

        if stamperScale != 1.0 {
            NSGraphicsContext.restoreGraphicsState()
        }

    }

    override func mouseMoved(with event: NSEvent) {
        mouseLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard !isAnimatingPress else { return }
        mouseLocation = convert(event.locationInWindow, from: nil)
        animatePress()
    }

    private func animatePress() {
        isAnimatingPress = true
        let captureRect = stampRect
        let start = CACurrentMediaTime()

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            let elapsed = CACurrentMediaTime() - start
            let progress = min(elapsed / self.pressAnimationDuration, 1.0)

            if progress < 0.5 {
                let t = progress / 0.5
                self.stamperScale = 1.0 - (1.0 - self.pressMinScale) * (t * t)
            } else {
                let t = (progress - 0.5) / 0.5
                self.stamperScale = self.pressMinScale + (1.0 - self.pressMinScale) * (1.0 - (1.0 - t) * (1.0 - t))
            }

            self.needsDisplay = true

            if progress >= 1.0 {
                timer.invalidate()
                self.animationTimer = nil
                self.stamperScale = 1.0
                self.needsDisplay = true
                self.animateFadeOut(captureRect: captureRect)
            }
        }
    }

    private func animateFadeOut(captureRect: NSRect) {
        let start = CACurrentMediaTime()

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            let elapsed = CACurrentMediaTime() - start
            let progress = min(elapsed / self.fadeOutDuration, 1.0)
            // Ease-out (quadratic)
            let eased = 1.0 - (1.0 - progress) * (1.0 - progress)
            self.stamperOpacity = 1.0 - eased

            self.needsDisplay = true

            if progress >= 1.0 {
                timer.invalidate()
                self.animationTimer = nil
                self.stamperOpacity = 1.0
                self.isAnimatingPress = false
                self.delegate?.overlayViewDidClick(stampRect: captureRect)
            }
        }
    }

    override func magnify(with event: NSEvent) {
        userScale = max(minUserScale, min(maxUserScale, userScale + event.magnification))
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        // Also support scroll wheel with ctrl/cmd for resizing
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            let delta = event.scrollingDeltaY * 0.01
            userScale = max(minUserScale, min(maxUserScale, userScale + delta))
            needsDisplay = true
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            delegate?.overlayViewDidCancel()
        }
    }
}
