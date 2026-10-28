import AppKit

/// Menu natif du clic droit (ou clic avec Option) sur l’icône de la barre des menus.
/// Il ajoute des actions rapides sans modifier le panneau SwiftUI existant.
@MainActor
final class MenuBarContextMenuController {
    static let shared = MenuBarContextMenuController()

    private weak var statusItem: NSStatusItem?
    private var monitor: Any?
    private var actionTarget: MenuActionTarget?

    private init() {}

    func configure(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown, .leftMouseDown]) { [weak self] event in
            guard let self, let button = self.statusItem?.button,
                  event.window === button.window,
                  button.bounds.contains(button.convert(event.locationInWindow, from: nil)) else { return event }

            let isRightClick = event.type == .rightMouseDown
            let isOptionClick = event.type == .leftMouseDown && event.modifierFlags.contains(.option)
            guard isRightClick || isOptionClick else { return event }

            self.presentMenu()
            return nil
        }
    }

    private func presentMenu() {
        guard let statusItem else { return }
        let model = AdvancedKeyGlowModel.shared
        model.isMenuPresented = false

        let menu = buildMenu(for: model)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu(for model: AdvancedKeyGlowModel) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let target = MenuActionTarget()
        actionTarget = target

        let summary = NSMenuItem(title: summaryTitle(model), action: nil, keyEquivalent: "")
        summary.isEnabled = false
        menu.addItem(summary)
        menu.addItem(.separator())

        let step = Int((model.stepSize * 100).rounded())
        add("Augmenter de \(step) %", to: menu, target: target) { model.step(1) }
        add("Diminuer de \(step) %", to: menu, target: target) { model.step(-1) }

        if (model.brightness ?? 0) > 0.001 {
            add("Éteindre le clavier", to: menu, target: target) { model.turnOff() }
        } else {
            add("Rétablir \(Int((model.previousBrightness * 100).rounded())) %", to: menu, target: target) { model.restorePrevious() }
        }

        menu.addItem(.separator())

        let presetsItem = NSMenuItem(title: "Presets", action: nil, keyEquivalent: "")
        let presetsMenu = NSMenu(title: "Presets")
        for preset in model.profiles {
            let item = NSMenuItem(
                title: "\(preset.name) — \(Int((preset.brightness * 100).rounded())) %",
                action: #selector(MenuActionTarget.perform(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.state = model.activePreset?.id == preset.id ? .on : .off
            register(item, action: { model.applyPreset(id: preset.id) }, target: target)
            presetsMenu.addItem(item)
        }
        presetsItem.submenu = presetsMenu
        menu.addItem(presetsItem)

        let offItem = NSMenuItem(title: "Extinction temporaire", action: nil, keyEquivalent: "")
        let offMenu = NSMenu(title: "Extinction temporaire")
        if let until = model.temporaryOffUntil {
            add("Rétablir maintenant (fin à \(until.formatted(date: .omitted, time: .shortened)))", to: offMenu, target: target) {
                model.cancelTemporaryOff()
            }
        } else {
            for minutes in [15, 30, 60] {
                add(minutes == 60 ? "1 heure" : "\(minutes) minutes", to: offMenu, target: target) {
                    model.turnOffTemporarily(minutes: minutes)
                }
            }
        }
        offItem.submenu = offMenu
        menu.addItem(offItem)

        let hudItem = NSMenuItem(title: "Afficher le HUD", action: #selector(MenuActionTarget.perform(_:)), keyEquivalent: "")
        hudItem.target = target
        hudItem.state = model.showHUD ? .on : .off
        register(hudItem, action: { model.setShowHUD(!model.showHUD) }, target: target)
        menu.addItem(hudItem)

        menu.addItem(.separator())
        add("Réglages…", to: menu, target: target, key: ",") { MainWindowController.shared.show() }
        add("Quitter KeyGlow", to: menu, target: target, key: "q") { model.quit() }
        return menu
    }

    private func summaryTitle(_ model: AdvancedKeyGlowModel) -> String {
        guard let brightness = model.brightness else { return "Rétroéclairage indisponible" }
        if brightness < 0.001 { return "Clavier éteint" }
        let preset = model.activePreset.map { " · \($0.name)" } ?? ""
        return "Luminosité : \(Int((brightness * 100).rounded())) %\(preset)"
    }

    @discardableResult
    private func add(
        _ title: String,
        to menu: NSMenu,
        target: MenuActionTarget,
        key: String = "",
        state: NSControl.StateValue = .off,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(MenuActionTarget.perform(_:)), keyEquivalent: key)
        item.target = target
        item.state = state
        register(item, action: action, target: target)
        menu.addItem(item)
        return item
    }

    private func register(_ item: NSMenuItem, action: @escaping () -> Void, target: MenuActionTarget) {
        let key = UUID().uuidString
        item.representedObject = key
        target.handlers[key] = action
    }
}

/// Retained by the controller while the menu is tracked.
@MainActor
private final class MenuActionTarget: NSObject {
    var handlers: [String: () -> Void] = [:]

    @objc func perform(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        handlers[key]?()
    }
}
