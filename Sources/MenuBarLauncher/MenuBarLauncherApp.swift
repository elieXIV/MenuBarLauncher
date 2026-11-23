import SwiftUI
import Carbon

@main
struct MenuBarLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var floatingWindow: NSWindow?
    var globalEventMonitor: Any?
    var localEventMonitor: Any?
    var currentShortcut = Shortcut.defaultShortcut
    var currentDisplayMode: DisplayMode = .popover

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSavedShortcut()
        loadSavedDisplayMode()
        setupMenuBar()
        setupGlobalHotkey()
        observeShortcutChanges()
        observeWebViewHeightChanges()
        observeWebViewWidthChanges()
        observeDisplayModeChanges()
    }

    func loadSavedDisplayMode() {
        if let modeString = UserDefaults.standard.string(forKey: "displayMode"),
           let mode = DisplayMode(rawValue: modeString) {
            currentDisplayMode = mode
        }
    }

    func observeDisplayModeChanges() {
        print("🔄 Setting up display mode change observer")
        NotificationCenter.default.addObserver(
            forName: .displayModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🔄 Received displayModeChanged notification")
            if let mode = notification.object as? DisplayMode {
                print("🔄 Mode from notification: \(mode)")
                // Defer the switch to the next run loop iteration to avoid crashing
                // when the SettingsView sheet is still handling the picker change
                // and its presenting view (LauncherView in floating window) gets deallocated
                DispatchQueue.main.async {
                    print("🔄 DispatchQueue.main.async executing switchDisplayMode")
                    self?.switchDisplayMode(to: mode)
                }
            } else {
                print("❌ Notification object is not DisplayMode: \(notification.object ?? "nil")")
            }
        }
    }

    func switchDisplayMode(to mode: DisplayMode) {
        print("🔄 switchDisplayMode called: \(mode)")
        currentDisplayMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "displayMode")

        // Dismiss any presented sheets FIRST
        if let window = floatingWindow {
            print("🔄 Dismissing floatingWindow sheets")
            window.contentViewController?.dismiss(nil)
        }
        if let popover = popover, popover.isShown {
            print("🔄 Closing popover")
            popover.performClose(nil)
        }

        // Now rebuild the UI for the new mode
        // Give a moment for dismissal to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.setupMenuBar()
        }
    }

    
    func loadSavedShortcut() {
        let keyCode = UInt16(UserDefaults.standard.integer(forKey: "globalShortcutKeyCode"))
        let modifiersRaw = UInt(UserDefaults.standard.integer(forKey: "globalShortcutModifiers"))

        if keyCode != 0 {
            currentShortcut = Shortcut(
                keyCode: keyCode,
                modifiers: NSEvent.ModifierFlags(rawValue: modifiersRaw)
            )
        }
    }

    func observeShortcutChanges() {
        NotificationCenter.default.addObserver(
            forName: .shortcutChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let shortcut = notification.object as? Shortcut {
                self?.updateShortcut(shortcut)
            }
        }
    }

    func observeWebViewHeightChanges() {
        NotificationCenter.default.addObserver(
            forName: .webViewHeightChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let height = notification.object as? CGFloat {
                self?.updatePopoverSize(width: nil, height: height)
            }
        }
    }

    func observeWebViewWidthChanges() {
        NotificationCenter.default.addObserver(
            forName: .webViewWidthChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let width = notification.object as? CGFloat {
                self?.updatePopoverSize(width: width, height: nil)
            }
        }
    }

    func updatePopoverSize(width: CGFloat?, height: CGFloat?) {
        let newWidth = width ?? 360
        let newHeight = height ?? 420
        let newSize = NSSize(width: newWidth, height: newHeight)

        if let popover = popover {
            popover.contentSize = newSize
            popover.contentViewController?.view.frame.size = newSize
        }
        if let window = floatingWindow {
            var frame = window.frame
            frame.size = newSize
            window.setFrame(frame, display: true, animate: true)
        }
    }

    func updateShortcut(_ shortcut: Shortcut) {
        currentShortcut = shortcut
        setupGlobalHotkey() // Re-setup with new shortcut
    }

    func setupMenuBar() {
        // Clean up previous status item to avoid memory leak and duplicate menu bar icons
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2.fill", accessibilityDescription: "Launcher")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let contentView = LauncherView()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 420)

        switch currentDisplayMode {
        case .popover:
            popover = NSPopover()
            popover?.contentSize = NSSize(width: 360, height: 420)
            popover?.behavior = .transient
            popover?.animates = true
            popover?.contentViewController = NSViewController()
            popover?.contentViewController?.view = hostingView

        case .floatingWindow:
            floatingWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            floatingWindow?.title = "MenuBarLauncher"
            floatingWindow?.titlebarAppearsTransparent = true
            floatingWindow?.titleVisibility = .hidden
            floatingWindow?.isMovableByWindowBackground = true
            floatingWindow?.level = .floating
            floatingWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            floatingWindow?.contentViewController = NSViewController()
            floatingWindow?.contentViewController?.view = hostingView
            floatingWindow?.center()
            floatingWindow?.isReleasedWhenClosed = false
        }
    }

    func setupGlobalHotkey() {
        // Remove existing monitors
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }

        // Monitor for custom shortcut globally
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if self.matchesShortcut(event) {
                self.togglePopover(nil)
            }
        }

        // Also monitor locally (when app is focused)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.matchesShortcut(event) {
                self.togglePopover(nil)
                return nil // Consume the event
            }
            return event
        }
    }

    func matchesShortcut(_ event: NSEvent) -> Bool {
        let eventModifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        return event.keyCode == currentShortcut.keyCode &&
               eventModifiers == currentShortcut.modifiers
    }

    @objc func togglePopover(_ sender: Any?) {
        switch currentDisplayMode {
        case .popover:
            guard let button = statusItem?.button, let popover = popover else { return }

            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()

                // Focus the search field after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }

        case .floatingWindow:
            guard let window = floatingWindow else { return }

            if window.isVisible {
                window.orderOut(sender)
            } else {
                window.makeKeyAndOrderFront(sender)
                NSApp.activate(ignoringOtherApps: true)

                // Focus the search field after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }
        }
    }

    deinit {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        NotificationCenter.default.removeObserver(self)
    }
}