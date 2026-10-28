import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Login item launches stay in the menu bar; explicit launches (Finder, Spotlight, Dock) open the window.
    private var launchedAsLoginItem = false
    private var launchDate = Date()

    func applicationWillFinishLaunching(_ notification: Notification) {
        launchDate = Date()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenApplication(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppAppearance.applyStored()
        AppMenu.install()
        if !launchedAsLoginItem {
            MainWindowController.shared.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // A login item launch must stay in the menu bar; ignore the implicit reopen macOS can send right away.
        if launchedAsLoginItem, Date().timeIntervalSince(launchDate) < 2 {
            return true
        }
        MainWindowController.shared.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    @objc private func handleOpenApplication(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        let properties = event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        if properties == keyAELaunchedAsLogInItem {
            launchedAsLoginItem = true
        }
    }
}
