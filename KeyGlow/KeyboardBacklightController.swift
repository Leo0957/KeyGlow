import Foundation
import Darwin

/// The only private API in KeyGlow. CoreBrightness can disappear or change without notice.
@MainActor
final class KeyboardBacklightController {
    enum Failure: LocalizedError {
        case unavailable
        case invalidReading
        case writeRejected
        case unchanged

        var errorDescription: String? {
            switch self {
            case .unavailable: "Rétroéclairage ou interface CoreBrightness indisponible."
            case .invalidReading: "Lecture de la luminosité impossible."
            case .writeRejected: "macOS a refusé le réglage."
            case .unchanged: "Le niveau lu après le réglage n’a pas changé."
            }
        }
    }

    @objc private protocol SystemClient {
        @objc(copyPropertyForKey:keyboardID:)
        func copyProperty(forKey key: String, keyboardID: UInt64) -> Any?
        @objc(setProperty:withKey:keyboardID:)
        func setProperty(_ value: Any, withKey key: String, keyboardID: UInt64) -> Bool
    }

    @objc private protocol KeyboardClient {
        func copyKeyboardBacklightIDs() -> [NSNumber]?
        @objc(isKeyboardBuiltIn:)
        func isKeyboardBuiltIn(_ id: UInt64) -> Bool
        @objc(isAutoBrightnessEnabledForKeyboard:)
        func isAutoBrightnessEnabled(forKeyboard id: UInt64) -> Bool
        @objc(registerNotificationForKeys:keyboardID:block:)
        func registerNotification(forKeys keys: [String], keyboardID: UInt64, block: @escaping (Any?) -> Void)
        @objc(unregisterKeyboardNotificationBlock)
        func unregisterKeyboardNotificationBlock()
    }

    private static let key = "KeyboardBacklightBrightness"
    private let library: UnsafeMutableRawPointer
    private let systemObject: NSObject
    private let keyboardObject: NSObject
    private let system: SystemClient
    private let keyboard: KeyboardClient
    private let id: UInt64

    static func open() throws -> KeyboardBacklightController {
        guard let library = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW),
              let systemType = NSClassFromString("BrightnessSystemClient") as? NSObject.Type,
              let keyboardType = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
            throw Failure.unavailable
        }
        let systemObject = systemType.init()
        let keyboardObject = keyboardType.init()
        let requiredSystem = ["copyPropertyForKey:keyboardID:", "setProperty:withKey:keyboardID:"]
        let requiredKeyboard = ["copyKeyboardBacklightIDs", "isKeyboardBuiltIn:", "isAutoBrightnessEnabledForKeyboard:", "registerNotificationForKeys:keyboardID:block:", "unregisterKeyboardNotificationBlock"]
        guard requiredSystem.allSatisfy({ systemObject.responds(to: NSSelectorFromString($0)) }),
              requiredKeyboard.allSatisfy({ keyboardObject.responds(to: NSSelectorFromString($0)) }) else {
            dlclose(library)
            throw Failure.unavailable
        }
        let system = unsafeBitCast(systemObject, to: SystemClient.self)
        let keyboard = unsafeBitCast(keyboardObject, to: KeyboardClient.self)
        guard let ids = keyboard.copyKeyboardBacklightIDs(), !ids.isEmpty else {
            dlclose(library)
            throw Failure.unavailable
        }
        let id = (ids.first(where: { keyboard.isKeyboardBuiltIn($0.uint64Value) }) ?? ids[0]).uint64Value
        guard system.copyProperty(forKey: key, keyboardID: id) is NSNumber else {
            dlclose(library)
            throw Failure.unavailable
        }
        return .init(library: library, systemObject: systemObject, keyboardObject: keyboardObject, system: system, keyboard: keyboard, id: id)
    }

    private init(library: UnsafeMutableRawPointer, systemObject: NSObject, keyboardObject: NSObject, system: SystemClient, keyboard: KeyboardClient, id: UInt64) {
        self.library = library
        self.systemObject = systemObject
        self.keyboardObject = keyboardObject
        self.system = system
        self.keyboard = keyboard
        self.id = id
    }

    deinit { dlclose(library) }

    func read() throws -> Double {
        guard let value = system.copyProperty(forKey: Self.key, keyboardID: id) as? NSNumber else { throw Failure.invalidReading }
        return min(1, max(0, value.doubleValue))
    }

    var automaticEnabled: Bool { keyboard.isAutoBrightnessEnabled(forKeyboard: id) }

    func write(_ requested: Double) throws -> Double {
        let target = min(1, max(0, requested))
        let before = try read()
        if abs(before - target) < 0.002 { return before }
        guard system.setProperty(NSNumber(value: target), withKey: Self.key, keyboardID: id) else { throw Failure.writeRejected }
        let after = try read()
        guard abs(after - target) < 0.025, abs(after - before) > 0.001 else { throw Failure.unchanged }
        return after
    }

    func observe(_ handler: @escaping @MainActor () -> Void) {
        keyboard.registerNotification(forKeys: [Self.key], keyboardID: id) { _ in
            Task { @MainActor in handler() }
        }
    }

    func stopObserving() { keyboard.unregisterKeyboardNotificationBlock() }
}
