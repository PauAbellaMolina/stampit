import SwiftUI
import Carbon

@main
struct StampItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// Store a weak reference for the Carbon callback
private weak var sharedAppState: AppState?

class AppState: ObservableObject {
    let captureManager = CaptureManager()
    let stampStore = StampStore()
    private var hotkeyRef: EventHotKeyRef?

    init() {
        captureManager.onStampCaptured = { [weak stampStore] image in
            stampStore?.saveStamp(image: image)
        }
        sharedAppState = self
        registerGlobalHotkey()
    }

    private func registerGlobalHotkey() {
        let hotKeyID = EventHotKeyID(signature: OSType(0x53544D50), id: 1)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            sharedAppState?.captureManager.startCapture()
            return noErr
        }, 1, &eventType, nil, nil)

        RegisterEventHotKey(UInt32(kVK_ANSI_2),
                           UInt32(cmdKey | shiftKey),
                           hotKeyID,
                           GetApplicationEventTarget(),
                           0,
                           &hotkeyRef)
    }

    deinit {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let appState = AppState()
    let popover = NSPopover()
    var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "seal.fill", accessibilityDescription: "StampIt")
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        let menuView = StampMenuView(dismissAction: { [weak self] in
            self?.popover.performClose(nil)
        })
        .environmentObject(appState.captureManager)
        .environmentObject(appState.stampStore)

        popover.contentViewController = NSHostingController(rootView: menuView)
        popover.behavior = .transient
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in menu bar when window is closed
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func showMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let windowContent = StampMenuView(dismissAction: nil)
            .environmentObject(appState.captureManager)
            .environmentObject(appState.stampStore)

        let hostingController = NSHostingController(rootView: windowContent)

        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: screenHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "StampIt"
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController

        // Position at right edge of screen, full height
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let x = visibleFrame.maxX - 300
            let y = visibleFrame.origin.y
            window.setFrame(NSRect(x: x, y: y, width: 300, height: visibleFrame.height), display: true)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        mainWindow = window
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show Stamps", action: #selector(showStampsWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        if appState.stampStore.stamps.isEmpty {
            clearItem.isEnabled = false
        }
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit StampIt", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so left-click popover works again
    }

    @objc private func showStampsWindow() {
        showMainWindow()
    }

    @objc private func clearHistory() {
        appState.stampStore.clearAll()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
