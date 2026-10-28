import AppKit

/// Light / dark / system preference for the whole app.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let defaultsKey = "keyGlowAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Système"
        case .light: "Clair"
        case .dark: "Sombre"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var appKitAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    static var stored: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .system
    }

    @MainActor
    static func apply(_ appearance: AppAppearance) {
        UserDefaults.standard.set(appearance.rawValue, forKey: defaultsKey)
        NSApp?.appearance = appearance.appKitAppearance
    }

    @MainActor
    static func applyStored() { apply(stored) }
}
