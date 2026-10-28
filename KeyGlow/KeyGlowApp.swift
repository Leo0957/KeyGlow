import AppKit
import SwiftUI
import MenuBarExtraAccess

@main
struct KeyGlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AdvancedKeyGlowModel.shared

    var body: some Scene {
        MenuBarExtra("KeyGlow", image: "KeyGlowMenuBarNeutral") {
            AdvancedKeyGlowView(model: model)
        }
        .menuBarExtraAccess(isPresented: $model.isMenuPresented) { statusItem in
            model.configureStatusItem(statusItem)
        }
        .menuBarExtraStyle(.window)
    }
}
