import AppKit

/// Selector targets for the standard text actions served by the responder chain.
@objc private protocol StandardEditActions {
    func undo(_ sender: Any?)
    func redo(_ sender: Any?)
    func cut(_ sender: Any?)
    func copy(_ sender: Any?)
    func paste(_ sender: Any?)
    func selectAll(_ sender: Any?)
}

/// Minimal French main menu used while the app runs with a Dock icon.
/// The menu bar extra keeps its own panel and does not depend on this menu.
@MainActor
enum AppMenu {
    static func install() {
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenu())
        mainMenu.addItem(fileMenu())
        mainMenu.addItem(editMenu())
        mainMenu.addItem(windowMenu())
        NSApp.mainMenu = mainMenu
    }

    private static func appMenu() -> NSMenuItem {
        let menu = NSMenu(title: "KeyGlow")
        menu.addItem(item("À propos de KeyGlow", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp))
        menu.addItem(.separator())
        menu.addItem(item("Réglages…", #selector(MainWindowController.showSettings(_:)), key: ",", target: MainWindowController.shared))
        menu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let services = NSMenu(title: "Services")
        servicesItem.submenu = services
        NSApp.servicesMenu = services
        menu.addItem(servicesItem)

        menu.addItem(.separator())
        menu.addItem(item("Masquer KeyGlow", #selector(NSApplication.hide(_:)), key: "h", target: NSApp))
        menu.addItem(item("Masquer les autres", #selector(NSApplication.hideOtherApplications(_:)), key: "h", modifiers: [.command, .option], target: NSApp))
        menu.addItem(item("Tout afficher", #selector(NSApplication.unhideAllApplications(_:)), target: NSApp))
        menu.addItem(.separator())
        menu.addItem(item("Quitter KeyGlow", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))

        let root = NSMenuItem()
        root.submenu = menu
        return root
    }

    private static func fileMenu() -> NSMenuItem {
        let menu = NSMenu(title: "Fichier")
        menu.addItem(item("Fermer la fenêtre", #selector(NSWindow.performClose(_:)), key: "w"))
        let root = NSMenuItem(title: "Fichier", action: nil, keyEquivalent: "")
        root.submenu = menu
        return root
    }

    private static func editMenu() -> NSMenuItem {
        let menu = NSMenu(title: "Édition")
        menu.addItem(item("Annuler", #selector(StandardEditActions.undo(_:)), key: "z"))
        menu.addItem(item("Rétablir", #selector(StandardEditActions.redo(_:)), key: "z", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Couper", #selector(StandardEditActions.cut(_:)), key: "x"))
        menu.addItem(item("Copier", #selector(StandardEditActions.copy(_:)), key: "c"))
        menu.addItem(item("Coller", #selector(StandardEditActions.paste(_:)), key: "v"))
        menu.addItem(item("Tout sélectionner", #selector(StandardEditActions.selectAll(_:)), key: "a"))
        let root = NSMenuItem(title: "Édition", action: nil, keyEquivalent: "")
        root.submenu = menu
        return root
    }

    private static func windowMenu() -> NSMenuItem {
        let menu = NSMenu(title: "Fenêtre")
        menu.addItem(item("Réduire", #selector(NSWindow.performMiniaturize(_:)), key: "m"))
        menu.addItem(item("Zoom", #selector(NSWindow.performZoom(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Amener tout au premier plan", #selector(NSApplication.arrangeInFront(_:)), target: NSApp))
        NSApp.windowsMenu = menu
        let root = NSMenuItem(title: "Fenêtre", action: nil, keyEquivalent: "")
        root.submenu = menu
        return root
    }

    private static func item(
        _ title: String,
        _ action: Selector?,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = .command,
        target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        return item
    }
}
