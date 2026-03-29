import Cocoa

class ToastWindow: NSPanel {
    private static var current: ToastWindow?

    static func show(_ message: String) {
        current?.orderOut(nil)

        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.sizeToFit()

        let padding: CGFloat = 24
        let height: CGFloat = 32
        let width = label.frame.width + padding * 2

        let mouseLocation = NSEvent.mouseLocation
        let origin = NSPoint(
            x: mouseLocation.x - width / 2,
            y: mouseLocation.y + 30
        )

        let panel = ToastWindow(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        let backgroundView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        backgroundView.layer?.cornerRadius = height / 2

        label.frame = NSRect(x: padding, y: (height - label.frame.height) / 2, width: label.frame.width, height: label.frame.height)
        backgroundView.addSubview(label)

        panel.contentView = backgroundView
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        current = panel

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.3
                    panel.animator().alphaValue = 0
                }) {
                    panel.orderOut(nil)
                    if current === panel { current = nil }
                }
            }
        }
    }
}
