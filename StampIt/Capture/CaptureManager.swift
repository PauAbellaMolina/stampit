import Cocoa

class CaptureManager: ObservableObject {
    @Published var isCapturing = false

    private var overlayPanel: OverlayPanel?
    private var overlayView: OverlayView?
    private var eventMonitor: Any?

    var onStampCaptured: ((CGImage) -> Void)?

    func startCapture() {
        guard !isCapturing else { return }
        guard let screen = NSScreen.main else { return }

        isCapturing = true
        NSApp.activate(ignoringOtherApps: true)

        // Create overlay
        let view = OverlayView(frame: screen.frame)
        view.delegate = self

        let panel = OverlayPanel(screen: screen)
        panel.contentView = view

        // Monitor for Escape key globally (backup for key events)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.cancelCapture()
                return nil
            }
            return event
        }

        panel.makeKeyAndOrderFront(nil)

        overlayPanel = panel
        overlayView = view
    }

    func cancelCapture() {
        tearDown()
    }

    private func performCapture(rect: NSRect) {
        let captureRect = rect
        tearDown()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            guard let rawImage = await ScreenCapture.captureRect(captureRect) else { return }
            guard let stampedImage = StampBorderRenderer.applyStampBorder(to: rawImage) else { return }
            self.onStampCaptured?(stampedImage)
        }
    }

    private func tearDown() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
        overlayView = nil
        isCapturing = false
    }
}

extension CaptureManager: OverlayViewDelegate {
    func overlayViewDidClick(stampRect: NSRect) {
        performCapture(rect: stampRect)
    }

    func overlayViewDidCancel() {
        cancelCapture()
    }
}
