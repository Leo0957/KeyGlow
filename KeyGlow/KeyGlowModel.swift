import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

extension KeyboardShortcuts.Name {
    static let increase = Self("increase")
    static let decrease = Self("decrease")
    static let toggle = Self("toggle")
    static let openMenu = Self("openMenu")
}

@MainActor
@Observable
final class KeyGlowModel {
    private let controller: KeyboardBacklightController?
    private let defaults = UserDefaults.standard
    var brightness: Double?
    var automaticEnabled = false
    var error: String?
    var isMenuPresented = false
    var showsShortcuts = false
    var launchAtLogin = false
    private var lastNonzero: Double

    init() {
        lastNonzero = max(0.01, defaults.double(forKey: "lastNonzeroBrightness"))
        controller = try? KeyboardBacklightController.open()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if let controller {
            brightness = try? controller.read()
            automaticEnabled = controller.automaticEnabled
            controller.observe { [weak self] in self?.refresh() }
        } else {
            error = KeyboardBacklightController.Failure.unavailable.localizedDescription
        }
        KeyboardShortcuts.onKeyDown(for: .increase) { [weak self] in Task { @MainActor in self?.step(0.05) } }
        KeyboardShortcuts.onKeyDown(for: .decrease) { [weak self] in Task { @MainActor in self?.step(-0.05) } }
        KeyboardShortcuts.onKeyDown(for: .toggle) { [weak self] in Task { @MainActor in self?.toggle() } }
        KeyboardShortcuts.onKeyDown(for: .openMenu) { [weak self] in Task { @MainActor in self?.isMenuPresented.toggle() } }
    }

    func refresh() {
        guard let controller else { return }
        do {
            brightness = try controller.read()
            automaticEnabled = controller.automaticEnabled
        } catch { self.error = error.localizedDescription }
    }

    func set(_ value: Double) {
        guard let controller else { return }
        do {
            let actual = try controller.write(value)
            brightness = actual
            if actual > 0.001 {
                lastNonzero = actual
                defaults.set(actual, forKey: "lastNonzeroBrightness")
            }
            automaticEnabled = controller.automaticEnabled
            error = nil
        } catch {
            refresh()
            self.error = error.localizedDescription
        }
    }

    func step(_ delta: Double) {
        refresh()
        guard let brightness else { return }
        set(brightness + delta)
    }

    func toggle() {
        refresh()
        guard let brightness else { return }
        if brightness > 0.001 {
            lastNonzero = brightness
            defaults.set(brightness, forKey: "lastNonzeroBrightness")
            set(0)
        } else {
            set(lastNonzero)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            error = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            self.error = error.localizedDescription
        }
    }

    func quit() {
        controller?.stopObserving()
        NSApplication.shared.terminate(nil)
    }
}
