import AppKit
import SwiftUI

/// Hosts the single KeyGlow main window and switches the app between menu-bar-only and Dock modes.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private static let frameAutosaveName = "KeyGlowMainWindow"

    private var window: NSWindow?

    private override init() { super.init() }

    /// Opens the existing window, or creates it once, and brings the app forward.
    func show() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        AppMenu.install()
        let window = window ?? makeWindow()
        window.makeKeyAndOrderFront(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
    }

    @objc func showSettings(_ sender: Any?) { show() }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 730),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyGlow"
        window.subtitle = "Rétroéclairage du clavier"
        window.titlebarSeparatorStyle = .none
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 900, height: 620)
        window.contentView = NSHostingView(rootView: MainWindowView(model: .shared))
        window.delegate = self

        window.setFrameAutosaveName(Self.frameAutosaveName)
        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }

        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Keep KeyGlow usable from the menu bar with no Dock icon once its window is closed.
        guard NSApp.activationPolicy() == .regular else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
