import Cocoa
import CoreGraphics

struct PermissionHelper {
    static func hasScreenCapturePermission() -> Bool {
        if #available(macOS 15, *) {
            return CGPreflightScreenCaptureAccess()
        } else {
            let image = CGWindowListCreateImage(
                CGRect(x: 0, y: 0, width: 1, height: 1),
                .optionOnScreenOnly,
                kCGNullWindowID,
                []
            )
            return image != nil
        }
    }

    static func requestPermission() {
        if #available(macOS 15, *) {
            CGRequestScreenCaptureAccess()
        }
        // On macOS 14, the first CGWindowListCreateImage call triggers the prompt
    }

    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "StampIt needs screen recording permission to capture stamps. Please enable it in System Settings > Privacy & Security > Screen Recording, then relaunch StampIt."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
